#!/usr/bin/env bash
# =============================================================================
#  deploy_private_cloud.sh
#  Project  : Deployment of a Private Cloud using Open Source Libraries
#  Platform : OpenStack DevStack on Ubuntu 22.04
#  Author   : Nikhil
#  USN      : 23510078
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# ANSI colour helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

LOG_FILE="/var/log/deploy_private_cloud.log"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
info()    { echo -e "${CYAN}[INFO]  $(date '+%H:%M:%S')${RESET}  $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]    $(date '+%H:%M:%S')${RESET}  $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]  $(date '+%H:%M:%S')${RESET}  $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERROR] $(date '+%H:%M:%S')${RESET}  $*" | tee -a "$LOG_FILE" >&2; }

banner() {
  echo -e "${BLUE}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║      Private Cloud Deployment — OpenStack DevStack           ║"
  echo "║      Platform  : Ubuntu 22.04 LTS                           ║"
  echo "║      Services  : Nova · Neutron · Glance · Horizon          ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# ---------------------------------------------------------------------------
# Error trap — prints a failure message and exits
# ---------------------------------------------------------------------------
on_error() {
  local exit_code=$?
  local line_number=$1
  error "Deployment FAILED at line ${line_number} (exit code ${exit_code})."
  error "Check the full log at: ${LOG_FILE}"
  exit "${exit_code}"
}
trap 'on_error ${LINENO}' ERR

# ---------------------------------------------------------------------------
# 0.  Initialise log file
# ---------------------------------------------------------------------------
sudo touch "$LOG_FILE" 2>/dev/null || LOG_FILE="$HOME/deploy_private_cloud.log"
sudo chmod 666 "$LOG_FILE" 2>/dev/null || true

banner
info "Log file : ${LOG_FILE}"

# ---------------------------------------------------------------------------
# 1.  Root / sudo guard
# ---------------------------------------------------------------------------
check_root() {
  info "Checking user privileges …"
  if [[ "$EUID" -eq 0 ]]; then
    error "Do NOT run this script as root.  Run as a normal sudo-enabled user."
    exit 1
  fi
  if ! sudo -n true 2>/dev/null; then
    warn "sudo password may be required during this run."
  fi
  success "Privilege check passed (running as ${USER})."
}

# ---------------------------------------------------------------------------
# 2.  System compatibility checks
# ---------------------------------------------------------------------------
check_system() {
  info "Running system compatibility checks …"

  # OS
  if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS.  Ubuntu 22.04 required."; exit 1
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  if [[ "$ID" != "ubuntu" ]]; then
    error "This script requires Ubuntu.  Detected: ${ID}"; exit 1
  fi
  success "OS check passed : ${PRETTY_NAME}"

  # RAM  — minimum 8 GB
  local total_ram_mb
  total_ram_mb=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)
  if [[ "$total_ram_mb" -lt 8000 ]]; then
    warn "RAM is ${total_ram_mb} MB (< 8 GB).  DevStack may be unstable.  Proceeding …"
  else
    success "RAM check passed : ${total_ram_mb} MB available."
  fi

  # CPU  — minimum 2 cores
  local cpu_cores
  cpu_cores=$(nproc)
  if [[ "$cpu_cores" -lt 2 ]]; then
    warn "Only ${cpu_cores} CPU core detected.  Recommended: ≥ 2 cores."
  else
    success "CPU check passed : ${cpu_cores} cores available."
  fi

  # Disk — minimum 50 GB free on /opt
  local free_disk_gb
  free_disk_gb=$(df -BG /opt 2>/dev/null | awk 'NR==2{gsub(/G/,"",$4); print $4}')
  if [[ -z "$free_disk_gb" ]]; then
    free_disk_gb=$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')
  fi
  if [[ "$free_disk_gb" -lt 50 ]]; then
    warn "Free disk space is ${free_disk_gb} GB (recommended ≥ 50 GB).  Proceeding …"
  else
    success "Disk check passed : ${free_disk_gb} GB free."
  fi

  # Internet connectivity
  if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
    error "No internet connection.  DevStack requires package downloads."; exit 1
  fi
  success "Network check passed : internet reachable."
}

# ---------------------------------------------------------------------------
# 3.  Install system dependencies
# ---------------------------------------------------------------------------
install_dependencies() {
  info "Updating package index …"
  sudo apt-get update -y >> "$LOG_FILE" 2>&1

  info "Installing required system packages …"
  local pkgs=(
    git curl wget python3 python3-pip python3-venv
    net-tools iptables sudo lsb-release
    ca-certificates apt-transport-https
    gnupg software-properties-common
  )
  sudo apt-get install -y "${pkgs[@]}" >> "$LOG_FILE" 2>&1
  success "System packages installed."

  # Ensure pip is up-to-date
  sudo pip3 install --upgrade pip >> "$LOG_FILE" 2>&1
  success "pip upgraded."
}

# ---------------------------------------------------------------------------
# 4.  Create dedicated 'stack' user (DevStack convention)
# ---------------------------------------------------------------------------
create_stack_user() {
  info "Checking for 'stack' user …"
  if id "stack" &>/dev/null; then
    warn "'stack' user already exists.  Skipping creation."
  else
    info "Creating 'stack' user …"
    sudo useradd -s /bin/bash -d /opt/stack -m stack >> "$LOG_FILE" 2>&1
    echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack >> "$LOG_FILE"
    sudo chmod 0440 /etc/sudoers.d/stack
    success "'stack' user created with passwordless sudo."
  fi
}

# ---------------------------------------------------------------------------
# 5.  Clone DevStack
# ---------------------------------------------------------------------------
clone_devstack() {
  local DEVSTACK_DIR="/opt/stack/devstack"
  info "Cloning DevStack repository …"

  if sudo -u stack test -d "$DEVSTACK_DIR/.git"; then
    warn "DevStack already cloned at ${DEVSTACK_DIR}.  Pulling latest …"
    sudo -u stack git -C "$DEVSTACK_DIR" pull --ff-only >> "$LOG_FILE" 2>&1 || true
  else
    if sudo -u stack test -d "$DEVSTACK_DIR"; then
      warn "Cleaning up incomplete DevStack clone at ${DEVSTACK_DIR} …"
      sudo -u stack rm -rf "$DEVSTACK_DIR"
    fi
    sudo -u stack git clone \
      --depth 1 \
      https://opendev.org/openstack/devstack.git \
      "$DEVSTACK_DIR" >> "$LOG_FILE" 2>&1
  fi
  success "DevStack source ready at ${DEVSTACK_DIR}."
}

# ---------------------------------------------------------------------------
# 6.  Generate local.conf
# ---------------------------------------------------------------------------
generate_local_conf() {
  local DEVSTACK_DIR="/opt/stack/devstack"
  info "Generating local.conf …"

  # Detect primary network interface IP
  local HOST_IP
  HOST_IP=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')
  if [[ -z "$HOST_IP" ]]; then
    HOST_IP=$(hostname -I | awk '{print $1}')
  fi
  info "Detected host IP: ${HOST_IP}"

  sudo -u stack tee "$DEVSTACK_DIR/local.conf" > /dev/null <<EOF
[[local|localrc]]
# ── Passwords ──────────────────────────────────────────
ADMIN_PASSWORD=admin
DATABASE_PASSWORD=admin
RABBIT_PASSWORD=admin
SERVICE_PASSWORD=admin

# ── Host Configuration ─────────────────────────────────
HOST_IP=${HOST_IP}

# ── Core Services ──────────────────────────────────────
# Compute  (Nova)
enable_service n-api n-cond n-sch n-cpu n-cauth

# Networking (Neutron)
disable_service q-svc q-agt q-dhcp q-l3 q-meta
enable_service neutron q-svc q-agt q-dhcp q-l3 q-meta

# Identity (Keystone)
enable_service key

# Image (Glance)
enable_service g-api g-reg

# Block Storage (Cinder) — optional but lightweight
enable_service cinder c-api c-vol c-sch c-bak

# Dashboard (Horizon)
enable_service horizon

# Object Storage (Swift) — disabled to save resources
disable_service s-proxy s-object s-container s-account

# ── Log configuration ──────────────────────────────────
LOGFILE=/opt/stack/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True
SCREEN_LOGDIR=/opt/stack/logs

# ── Image configuration ────────────────────────────────
# Use Cirros (tiny test image) for fast provisioning
IMAGE_URLS="http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img"

# ── Tempest (integration tests) ───────────────────────
disable_service tempest

# ── Misc ───────────────────────────────────────────────
GIT_BASE=https://opendev.org
RECLONE=no
EOF

  success "local.conf written to ${DEVSTACK_DIR}/local.conf."
  info    "Detected HOST_IP = ${HOST_IP}  (used for dashboard URL below)."
}

# ---------------------------------------------------------------------------
# 7.  Run stack.sh
# ---------------------------------------------------------------------------
run_stack() {
  local DEVSTACK_DIR="/opt/stack/devstack"
  info "Starting OpenStack DevStack installation via stack.sh …"
  info "This may take 20–40 minutes depending on your internet speed."
  info "Full output is being captured to: /opt/stack/logs/stack.sh.log"
  echo ""

  # Run as 'stack' user; forward output to our log AND to terminal
  sudo -u stack bash -c "cd ${DEVSTACK_DIR} && ./stack.sh" \
    2>&1 | tee -a "$LOG_FILE"

  success "stack.sh completed successfully!"
}

# ---------------------------------------------------------------------------
# 8.  Print final summary
# ---------------------------------------------------------------------------
print_summary() {
  local HOST_IP
  HOST_IP=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')
  [[ -z "$HOST_IP" ]] && HOST_IP=$(hostname -I | awk '{print $1}')

  echo ""
  echo -e "${GREEN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║          ✅  Private Cloud Deployed Successfully!            ║"
  echo "╠══════════════════════════════════════════════════════════════╣"
  printf "║  🌐  Horizon Dashboard  : %-36s║\n" "http://${HOST_IP}/dashboard"
  printf "║  👤  Admin Username     : %-36s║\n" "admin"
  printf "║  🔑  Admin Password     : %-36s║\n" "admin"
  printf "║  📄  Deployment Log     : %-36s║\n" "${LOG_FILE}"
  echo "╠══════════════════════════════════════════════════════════════╣"
  echo "║  Services Available:                                         ║"
  echo "║    • Nova     (Compute)      → http://${HOST_IP}:8774       ║"
  echo "║    • Neutron  (Networking)   → http://${HOST_IP}:9696       ║"
  echo "║    • Glance   (Image)        → http://${HOST_IP}:9292       ║"
  echo "║    • Keystone (Identity)     → http://${HOST_IP}:5000       ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  info "OpenStack RC file is at: /opt/stack/devstack/openrc"
  info "Source it with:  source /opt/stack/devstack/openrc admin admin"
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
main() {
  check_root
  check_system
  install_dependencies
  create_stack_user
  clone_devstack
  generate_local_conf
  run_stack
  print_summary
}

main "$@"
