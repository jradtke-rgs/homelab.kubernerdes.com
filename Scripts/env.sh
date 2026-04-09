#!/usr/bin/env bash
# env.sh — Homelab environment configuration
#
# Source this from scripts that run on the admin node (nuc-00):
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/env.sh"
#
# Override ENVIRONMENT before sourcing to select a different environment:
#
#   ENVIRONMENT=enclave source "${SCRIPT_DIR}/env.sh"
#
# Scripts that run on remote nodes (cluster nodes, infra VMs) cannot source
# this file directly — they define ENVIRONMENT/DOMAIN inline at their top.

export ENVIRONMENT="${ENVIRONMENT:-homelab}"
export DOMAIN="kubernerdes.com"
export BASE_DOMAIN="${ENVIRONMENT}.${DOMAIN}"

# Admin and infra hosts
export ADMIN_HOST="nuc-00"
export DNS_HOST="nuc-00-01"
export DNS2_HOST="nuc-00-02"
export LB_HOST="nuc-00-03"

# IP addressing by environment
case "${ENVIRONMENT}" in
  homelab)
    export IP_PREFIX="10.0.0"
    export NIC_NAME="eno1"
    export HARVESTER_VERSION="v1.7.1"
    export NUC01_MAC="88:ae:dd:0b:90:70"
    export NUC02_MAC="1c:69:7a:ab:23:50"
    export NUC03_MAC="88:ae:dd:0b:af:9c"
    ;;
  enclave)
    export IP_PREFIX="10.10.12"
    export NIC_NAME="enp86s0"
    export HARVESTER_VERSION="v1.7.1-amd64-govt.1"
    export NUC01_MAC=""
    export NUC02_MAC=""
    export NUC03_MAC=""
    ;;
  *)
    echo "env.sh: unknown ENVIRONMENT '${ENVIRONMENT}'" >&2
    ;;
esac

# Admin web/repo server
export ADMIN_IP="${IP_PREFIX}.10"
export REPO_BASE="http://${ADMIN_IP}/${BASE_DOMAIN}"

# Harvester cluster
export HARVESTER_TOKEN="KentuckyHarvester"
export HARVESTER_PASSWORD="Passw0rd01"
export HARVESTER_VIP="${IP_PREFIX}.100"
export NUC01_IP="${IP_PREFIX}.101"
export NUC02_IP="${IP_PREFIX}.102"
export NUC03_IP="${IP_PREFIX}.103"
export GATEWAY="${IP_PREFIX}.1"
export DNS1_IP="${IP_PREFIX}.9"
export DNS2_IP="${IP_PREFIX}.8"

# RKE2 cluster — Rancher Manager
export RANCHER_VIP="${IP_PREFIX}.210"
export RANCHER_HOSTNAME="rancher.${BASE_DOMAIN}"

# RKE2 cluster — Observability
export OBS_VIP="${IP_PREFIX}.220"
export OBS_HOSTNAME="observability.${BASE_DOMAIN}"

# RKE2 cluster — Apps
export APPS_VIP="${IP_PREFIX}.230"
export APPS_HOSTNAME="apps.${BASE_DOMAIN}"

# Kubeconfig paths
export KUBECONFIG_RANCHER="${HOME}/.kube/${ENVIRONMENT}-rancher.kubeconfig"
export KUBECONFIG_OBS="${HOME}/.kube/${ENVIRONMENT}-observability.kubeconfig"
export KUBECONFIG_APPS="${HOME}/.kube/${ENVIRONMENT}-apps.kubeconfig"
