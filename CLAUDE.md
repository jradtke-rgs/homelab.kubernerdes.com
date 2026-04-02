# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This is a personal homelab environment built on Intel NUCs using **RGS Carbide** (Rancher Government Solutions). It is **not** an official RGS repository. The goal is to deploy and demonstrate:

- **Harvester** hypervisor cluster (3 NUCs)
- **Rancher Manager Server** (multi-cluster management)
- **SUSE Observability** stack
- **Applications Kubernetes cluster** with **SUSE Security (NeuVector)** installed

The repo is based on the earlier `../enclave.kubernerdes.com` project, refocused on a homelab context using RGS Carbide components.

## Architecture Overview

```
Admin Host (nuc-00) — Hauler, Harbor, DNS, PXE, Ansible control node
        ↓
Harvester Cluster (3x NUC i7-1360P) — Kubernetes-native hypervisor
        ↓
Infrastructure VMs (DNS, HAProxy + Keepalived for VIP/HA)
        ↓
RKE2 Clusters on SL-Micro VMs:
  - Rancher Manager Server cluster (3 nodes + VIP)
  - Observability cluster (3 nodes + VIP)
  - Applications cluster (3 nodes + VIP) ← NeuVector installed here
```

**Key design principles:**
- **Air-gapped deployment:** All images/charts pulled via Hauler and cached in Harbor; no external pulls at deploy time
- **Self-signed PKI:** Homelab root CA generated on nuc-00, distributed to all system trust stores
- **Registry mirror:** Harvester and RKE2 containerd configured with `system-default-registry` pointing to Harbor
- **Interactive scripts:** Bash scripts are meant to be stepped through and understood, not blindly executed

## Deployment Workflow

Scripts in `Scripts/` follow a numbered Day 1/Day 2 sequence:

| Script | Purpose |
|--------|---------|
| `02_setup_ca.sh` | Generate root CA, distribute to system trust store |
| `07_post_configure_harvester.sh` | Trust CA, configure registry mirror to Harbor, upload cloud images |
| `10_install_rancher_manager.sh` | Deploy RKE2 + Rancher Manager Server on 3 VMs |
| `20_install_RGS_security.sh` | Deploy NeuVector on the apps cluster |
| `21_install_observability.sh` | Deploy SUSE Observability stack |
| `install_RKE2.sh` | Install RKE2 on cluster nodes via Harbor |

## Ansible

```bash
cd Ansible/
ansible -i hosts all -a "uptime"
ansible -i hosts all -m shell -a "command" -b
ansible-playbook -i hosts site.yaml
```

Inventory groups: `HarvesterEdge`, `InfraNodesPhysical` (nuc-00), `InfraNodesVirtualMachines` (nuc-00-01/02/03)

## Key Directories

- `Scripts/` — Numbered bash scripts for Day 1/2 deployment
- `Ansible/` — Playbooks and inventory for configuration management
- `Files/` — Config templates: cloud-init YAMLs, DNS (BIND), HAProxy, Apache HTTP, PXE menus
- `Docs/` — Operational guides (PXE, etc.)
- `Images/` — Architecture diagrams

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Hypervisor | Harvester |
| Kubernetes | RKE2, K3s (alternative) |
| Node OS | SL-Micro (SUSE) |
| Cluster management | Rancher Manager Server v3.x |
| Security | NeuVector (SUSE Security) |
| Observability | SUSE Observability |
| Image registry | Harbor |
| Artifact manager | Hauler (air-gap) |
| PKI | OpenSSL self-signed CA |
| DNS | BIND |
| Load balancing | HAProxy + Keepalived |
| Config management | Ansible |
