#!/usr/bin/env bash
# =============================================================================
#  cleanup.sh
#  Unstack DevStack and optionally remove all OpenStack data
#  Project  : Deployment of a Private Cloud using Open Source Libraries
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]  ${RESET}$*"; }
success() { echo -e "${GREEN}[OK]    ${RESET}$*"; }
warn()    { echo -e "${YELLOW}[WARN]  ${RESET}$*"; }
error()   { echo -e "${RED}[ERROR] ${RESET}$*" >&2; }

banner() {
  echo -e "${RED}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║           Private Cloud — Cleanup / Unstack Script          ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

banner

# Confirm before proceeding
read -r -p "$(echo -e "${YELLOW}WARNING: This will stop all OpenStack services. Continue? [y/N]: ${RESET}")" confirm
if [[ "${confirm,,}" != "y" ]]; then
  info "Cleanup aborted by user."
  exit 0
fi

DEVSTACK_DIR="/opt/stack/devstack"

# ---------------------------------------------------------------------------
# 1. Run unstack.sh
# ---------------------------------------------------------------------------
if [[ -f "$DEVSTACK_DIR/unstack.sh" ]]; then
  info "Running unstack.sh …"
  sudo -u stack bash -c "cd ${DEVSTACK_DIR} && ./unstack.sh" || warn "unstack.sh returned non-zero."
  success "OpenStack services stopped."
else
  warn "unstack.sh not found.  Skipping graceful unstack."
fi

# ---------------------------------------------------------------------------
# 2. Optionally run clean.sh  (removes ALL DevStack data)
# ---------------------------------------------------------------------------
read -r -p "$(echo -e "${YELLOW}Also run clean.sh (removes ALL data)? [y/N]: ${RESET}")" deep_clean
if [[ "${deep_clean,,}" == "y" ]]; then
  if [[ -f "$DEVSTACK_DIR/clean.sh" ]]; then
    info "Running clean.sh …"
    sudo -u stack bash -c "cd ${DEVSTACK_DIR} && ./clean.sh" || warn "clean.sh returned non-zero."
    success "All DevStack data removed."
  else
    warn "clean.sh not found."
  fi
fi

# ---------------------------------------------------------------------------
# 3. Remove log files
# ---------------------------------------------------------------------------
read -r -p "$(echo -e "${YELLOW}Remove log files under /opt/stack/logs? [y/N]: ${RESET}")" rm_logs
if [[ "${rm_logs,,}" == "y" ]]; then
  sudo rm -rf /opt/stack/logs
  success "Logs removed."
fi

echo ""
success "Cleanup complete.  You may re-run deploy_private_cloud.sh to start fresh."
