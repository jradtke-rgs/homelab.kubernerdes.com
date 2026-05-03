#!/usr/bin/env bash
# env.sh — Central environment configuration for homelab.kubernerdes.com
#
# Source this from any script running on the admin node (nuc-00):
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/env.sh"
#
# Override ENVIRONMENT before sourcing to select a different environment:
#
#   ENVIRONMENT=carbide source "${SCRIPT_DIR}/env.sh"
#
# Scripts that run on remote nodes (cluster VMs, infra VMs) cannot source
# this file directly — they set ENVIRONMENT/DOMAIN/IP_PREFIX inline at top.
# See install_RKE2.sh and nuc-00-*/post_install.sh for that pattern.
#
# ENVIRONMENTS — all share the 10.10.12.0/22 supernet; each occupies one /24:
#   carbide    — 10.10.12.0/24 — nuc-01/02/03 — RGS software from RGS registry
#   enclave    — 10.10.13.0/24 — nuc-11/12/13 — RGS via Hauler + Harbor (air-gap)
#   community  — 10.10.14.0/24 — nuc-21/22/23 — SUSE/upstream bits, public registries
#   (reserved) — 10.10.15.0/24 — DHCP dynamic pool
#
# NUC01_HOST / NUC02_HOST / NUC03_HOST are set per environment in env.d/:
#   carbide:   nuc-01 / nuc-02 / nuc-03
#   enclave:   nuc-11 / nuc-12 / nuc-13
#   community: nuc-21 / nuc-22 / nuc-23

export ENVIRONMENT="${ENVIRONMENT:-community}"
export DOMAIN="kubernerdes.com"
export BASE_DOMAIN="${ENVIRONMENT}.${DOMAIN}"

# ---------------------------------------------------------------------------
# IP addressing
# ---------------------------------------------------------------------------

# Per-environment /24 prefix — all within the 10.10.12.0/22 supernet
case "${ENVIRONMENT}" in
  carbide)   export IP_PREFIX="10.10.12" ;;
  enclave)   export IP_PREFIX="10.10.13" ;;
  community) export IP_PREFIX="10.10.14" ;;
  *) echo "ERROR: Unknown ENVIRONMENT '${ENVIRONMENT}'" >&2; return 1 ;;
esac

# Supernet constants (fixed — shared by all environments and the DHCP pool)
export SUPERNET_PREFIX="10.10.12"
export SUBNET_CIDR="${SUPERNET_PREFIX}.0/22"
export SUBNET_MASK="255.255.252.0"
export GATEWAY="${SUPERNET_PREFIX}.1"

# DHCP dynamic pool — last /24 of the /22, reserved across all environments
export DHCP_POOL_PREFIX="10.10.15"
export DHCP_RANGE_START="${DHCP_POOL_PREFIX}.1"
export DHCP_RANGE_END="${DHCP_POOL_PREFIX}.254"

# ---------------------------------------------------------------------------
# Infrastructure hosts
# ---------------------------------------------------------------------------
export ADMIN_HOST="nuc-00"
export DNS_HOST="nuc-00-01"
export DNS2_HOST="nuc-00-02"
export LB_HOST="nuc-00-03"

# Infrastructure IPs — DNS is shared across all environments (supernet addresses)
export DNS1_IP="${SUPERNET_PREFIX}.8"
export DNS2_IP="${SUPERNET_PREFIX}.9"
export ADMIN_IP="${IP_PREFIX}.10"
export LB_IP="${IP_PREFIX}.93"

# Admin web/repo server — repo is cloned to Apache web root and served here
export REPO_BASE="http://${ADMIN_IP}/${BASE_DOMAIN}"

# ---------------------------------------------------------------------------
# Harvester cluster
# ---------------------------------------------------------------------------
export HARVESTER_TOKEN="KentuckyHarvester"
export HARVESTER_PASSWORD="Passw0rd01"
export HARVESTER_VIP="${IP_PREFIX}.100"
export NUC01_IP="${IP_PREFIX}.101"
export NUC02_IP="${IP_PREFIX}.102"
export NUC03_IP="${IP_PREFIX}.103"

# ---------------------------------------------------------------------------
# RKE2 cluster — Rancher Manager
# ---------------------------------------------------------------------------
export RANCHER_VIP="${IP_PREFIX}.210"
export RANCHER_HOSTNAME="rancher.${BASE_DOMAIN}"
export RANCHER_NODE_01="${IP_PREFIX}.211"
export RANCHER_NODE_02="${IP_PREFIX}.212"
export RANCHER_NODE_03="${IP_PREFIX}.213"

# ---------------------------------------------------------------------------
# RKE2 cluster — Observability
# ---------------------------------------------------------------------------
export OBS_VIP="${IP_PREFIX}.220"
export OBS_HOSTNAME="observability.${BASE_DOMAIN}"
export OBS_NODE_01="${IP_PREFIX}.221"
export OBS_NODE_02="${IP_PREFIX}.222"
export OBS_NODE_03="${IP_PREFIX}.223"

# ---------------------------------------------------------------------------
# RKE2 cluster — Applications
# ---------------------------------------------------------------------------
export APPS_VIP="${IP_PREFIX}.230"
export APPS_HOSTNAME="apps.${BASE_DOMAIN}"
export APPS_NODE_01="${IP_PREFIX}.231"
export APPS_NODE_02="${IP_PREFIX}.232"
export APPS_NODE_03="${IP_PREFIX}.233"

# ---------------------------------------------------------------------------
# Shared HAProxy variables — nuc-00-03 serves carbide, enclave, and community
# from a single haproxy.cfg; these vars are used by the haproxy template
# regardless of which ENVIRONMENT context env.sh is sourced in.
# ---------------------------------------------------------------------------
_CARBIDE_PFX="10.10.12"
_ENCLAVE_PFX="10.10.13"
_COMMUNITY_PFX="10.10.14"

export CARBIDE_RANCHER_VIP="${_CARBIDE_PFX}.210"
export CARBIDE_RANCHER_NODE_01="${_CARBIDE_PFX}.211"
export CARBIDE_RANCHER_NODE_02="${_CARBIDE_PFX}.212"
export CARBIDE_RANCHER_NODE_03="${_CARBIDE_PFX}.213"

export CARBIDE_OBS_VIP="${_CARBIDE_PFX}.220"
export CARBIDE_OBS_NODE_01="${_CARBIDE_PFX}.221"
export CARBIDE_OBS_NODE_02="${_CARBIDE_PFX}.222"
export CARBIDE_OBS_NODE_03="${_CARBIDE_PFX}.223"

export CARBIDE_APPS_VIP="${_CARBIDE_PFX}.230"
export CARBIDE_APPS_NODE_01="${_CARBIDE_PFX}.231"
export CARBIDE_APPS_NODE_02="${_CARBIDE_PFX}.232"
export CARBIDE_APPS_NODE_03="${_CARBIDE_PFX}.233"

export ENCLAVE_RANCHER_VIP="${_ENCLAVE_PFX}.210"
export ENCLAVE_RANCHER_NODE_01="${_ENCLAVE_PFX}.211"
export ENCLAVE_RANCHER_NODE_02="${_ENCLAVE_PFX}.212"
export ENCLAVE_RANCHER_NODE_03="${_ENCLAVE_PFX}.213"

export ENCLAVE_OBS_VIP="${_ENCLAVE_PFX}.220"
export ENCLAVE_OBS_NODE_01="${_ENCLAVE_PFX}.221"
export ENCLAVE_OBS_NODE_02="${_ENCLAVE_PFX}.222"
export ENCLAVE_OBS_NODE_03="${_ENCLAVE_PFX}.223"

export ENCLAVE_APPS_VIP="${_ENCLAVE_PFX}.230"
export ENCLAVE_APPS_NODE_01="${_ENCLAVE_PFX}.231"
export ENCLAVE_APPS_NODE_02="${_ENCLAVE_PFX}.232"
export ENCLAVE_APPS_NODE_03="${_ENCLAVE_PFX}.233"

export COMMUNITY_RANCHER_VIP="${_COMMUNITY_PFX}.210"
export COMMUNITY_RANCHER_NODE_01="${_COMMUNITY_PFX}.211"
export COMMUNITY_RANCHER_NODE_02="${_COMMUNITY_PFX}.212"
export COMMUNITY_RANCHER_NODE_03="${_COMMUNITY_PFX}.213"

export COMMUNITY_OBS_VIP="${_COMMUNITY_PFX}.220"
export COMMUNITY_OBS_NODE_01="${_COMMUNITY_PFX}.221"
export COMMUNITY_OBS_NODE_02="${_COMMUNITY_PFX}.222"
export COMMUNITY_OBS_NODE_03="${_COMMUNITY_PFX}.223"

export COMMUNITY_APPS_VIP="${_COMMUNITY_PFX}.230"
export COMMUNITY_APPS_NODE_01="${_COMMUNITY_PFX}.231"
export COMMUNITY_APPS_NODE_02="${_COMMUNITY_PFX}.232"
export COMMUNITY_APPS_NODE_03="${_COMMUNITY_PFX}.233"

unset _CARBIDE_PFX _ENCLAVE_PFX _COMMUNITY_PFX

# ---------------------------------------------------------------------------
# Kubeconfig paths (stored on nuc-00)
# ---------------------------------------------------------------------------
export KUBECONFIG_HARVESTER="${HOME}/.kube/${ENVIRONMENT}-harvester.kubeconfig"
export KUBECONFIG_RANCHER="${HOME}/.kube/${ENVIRONMENT}-rancher.kubeconfig"
export KUBECONFIG_OBS="${HOME}/.kube/${ENVIRONMENT}-observability.kubeconfig"
export KUBECONFIG_APPS="${HOME}/.kube/${ENVIRONMENT}-apps.kubeconfig"

# ---------------------------------------------------------------------------
# SSH key used for cluster node access
# ---------------------------------------------------------------------------
export SSH_KEY="${HOME}/.ssh/id_rsa-${ENVIRONMENT}"
export SSH_OPTS="-i ${SSH_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=10"

# ---------------------------------------------------------------------------
# Source environment-specific variables
# (registry sources, image versions, credentials, hardware MACs)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.d/community.sh
source "${SCRIPT_DIR}/env.d/${ENVIRONMENT}.sh"
