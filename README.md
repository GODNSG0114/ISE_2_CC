# 🌩️ Private Cloud Deployment using OpenStack

> **Project:** Deployment of a Private Cloud using Open Source Libraries  
> **Author:** Nikhil | **USN:** 23510078  
> **Platform:** OpenStack DevStack on Ubuntu 22.04 LTS

---

## 📌 What is This Project?

This project sets up a **fully functional private cloud** using **OpenStack** — the same open-source cloud platform used by enterprises worldwide. It automates the entire installation of a multi-service cloud environment on a single Ubuntu machine using **DevStack**.

Think of it as your own mini AWS/Azure — running on your own hardware.

---

## 🧱 Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   OpenStack Private Cloud                │
├──────────────┬──────────────┬──────────────┬────────────┤
│   Keystone   │    Glance    │     Nova     │  Neutron   │
│  (Identity)  │   (Images)   │  (Compute)   │ (Network)  │
│  Port: 5000  │  Port: 9292  │  Port: 8774  │ Port: 9696 │
├──────────────┴──────────────┴──────────────┴────────────┤
│              Horizon Dashboard  (Port: 80)               │
├──────────────────────────┬──────────────────────────────┤
│   MariaDB (Database)     │   RabbitMQ (Message Queue)   │
└──────────────────────────┴──────────────────────────────┘
```

### Services Included

| Service | Role | Port |
|---------|------|------|
| **Keystone** | Identity & Authentication | 5000, 35357 |
| **Glance** | VM Image Registry | 9292 |
| **Nova** | Virtual Machine Compute | 8774 |
| **Neutron** | Virtual Networking | 9696 |
| **Horizon** | Web Dashboard (UI) | 80 |
| **MariaDB** | Database Backend | 3306 |
| **RabbitMQ** | Message Queue | 5672, 15672 |

---

## 📁 Project Files

```
├── deploy_private_cloud.sh   # Main deployment script (DevStack on Ubuntu)
├── docker-compose.yml        # Docker-based simulation (dev/demo environment)
├── cleanup.sh                # Unstack and clean up all services
└── README.md                 # This file
```

---

## 🚀 Deployment Options

### Option A — Full DevStack on Ubuntu 22.04 (Recommended for Demo)

This is the **real deployment** — installs actual OpenStack services on a VM.

#### Prerequisites

| Requirement | Minimum |
|-------------|---------|
| OS | Ubuntu 22.04 LTS |
| RAM | 8 GB (16 GB recommended) |
| CPU | 2 cores (4 recommended) |
| Disk | 50 GB free |
| Network | Internet access required |

#### Steps

```bash
# 1. Clone or copy this project to your Ubuntu machine
git clone <your-repo-url>
cd <project-folder>

# 2. Make the script executable
chmod +x deploy_private_cloud.sh

# 3. Run the deployment (do NOT run as root)
./deploy_private_cloud.sh
```

> ⏱️ Installation takes **20–40 minutes** depending on internet speed.

#### After Deployment

Once complete, you'll see:

```
╔══════════════════════════════════════════════════════════════╗
║          ✅  Private Cloud Deployed Successfully!            ║
╠══════════════════════════════════════════════════════════════╣
║  🌐  Horizon Dashboard  : http://<YOUR-IP>/dashboard         ║
║  👤  Admin Username     : admin                              ║
║  🔑  Admin Password     : admin                              ║
╚══════════════════════════════════════════════════════════════╝
```

**Access the dashboard:** Open `http://<YOUR-IP>/dashboard` in your browser.

---

### Option B — Docker Compose (Quick Demo / Dev Environment)

Use this if you want a **fast simulation** without a full Ubuntu VM.

#### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed
- [Docker Compose](https://docs.docker.com/compose/install/) installed

#### Steps

```bash
# 1. Start all services
docker compose up -d

# 2. Check all containers are running
docker compose ps

# 3. View logs (optional)
docker compose logs -f
```

#### Access Points (Docker)

| Service | URL |
|---------|-----|
| Horizon Dashboard | http://localhost:80 |
| Keystone API | http://localhost:5000 |
| Glance API | http://localhost:9292 |
| Nova API | http://localhost:8774 |
| Neutron API | http://localhost:9696 |
| RabbitMQ Management | http://localhost:15672 |

**Login credentials:**
- Username: `admin`
- Password: `admin`

#### Stop Docker Services

```bash
docker compose down
```

---

## 🧹 Cleanup (DevStack)

To stop and remove the DevStack deployment:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

The script will ask:
1. Stop all OpenStack services (`unstack.sh`)
2. Remove all data (`clean.sh`) — optional
3. Delete log files — optional

---

## 🎓 Demo Guide for Teacher Presentation

### Step-by-Step Demo Flow

#### 1. Show the Dashboard
- Open browser → `http://<YOUR-IP>/dashboard`
- Login with `admin` / `admin`
- Show the **Overview** page — it displays cloud resource usage

#### 2. Create a Virtual Machine (Instance)
```
Compute → Instances → Launch Instance
  - Instance Name: demo-vm
  - Source: cirros (tiny test image, ~15MB)
  - Flavor: m1.tiny
  - Network: private
→ Click "Launch"
```

#### 3. Show Networking
```
Network → Network Topology
```
- Visual diagram of virtual networks and connected VMs

#### 4. Show Image Management
```
Compute → Images
```
- Cirros image is pre-loaded — this is how cloud VMs boot

#### 5. Use the CLI (OpenStack RC)
```bash
source /opt/stack/devstack/openrc admin admin

# List running VMs
openstack server list

# List available images
openstack image list

# List networks
openstack network list
```

#### 6. Show Logs (Proof of Deployment)
```bash
cat /var/log/deploy_private_cloud.log
```

---

## 🔗 Deployable Link

> For a live demo, deploy on a cloud VM and share the IP:

| Platform | How to Deploy |
|----------|--------------|
| **AWS EC2** | Launch Ubuntu 22.04 t2.xlarge → run `deploy_private_cloud.sh` → access `http://<EC2-PUBLIC-IP>/dashboard` |
| **Google Cloud** | Launch Ubuntu 22.04 n1-standard-4 → same steps |
| **Azure** | Ubuntu 22.04 Standard_D4s_v3 → same steps |
| **Local VM** | VirtualBox / VMware with Ubuntu 22.04, 8GB RAM |

**Live Dashboard URL format:** `http://<SERVER-IP>/dashboard`

---

## 🛠️ Troubleshooting

| Issue | Fix |
|-------|-----|
| Script fails at `stack.sh` | Check `/opt/stack/logs/stack.sh.log` for details |
| Dashboard not loading | Ensure port 80 is open in firewall: `sudo ufw allow 80` |
| Low RAM warning | Close other apps; 8GB minimum required |
| Docker containers not starting | Run `docker compose logs <service-name>` to debug |
| Permission denied | Do NOT run as root; use a sudo-enabled normal user |

---

## 📚 References

- [OpenStack Official Docs](https://docs.openstack.org/)
- [DevStack Documentation](https://docs.openstack.org/devstack/latest/)
- [OpenStack Architecture Guide](https://docs.openstack.org/arch-design/)

---

*Project submitted for academic evaluation — Private Cloud using Open Source Libraries*
