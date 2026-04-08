#!/usr/bin/env bash
# env.sh — Homelab environment configuration
#
# Source this from scripts that run on the admin node (nuc-00):
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/env.sh"
#
# Scripts that run on remote nodes (cluster nodes, infra VMs) cannot source
# this file directly — they define ENVIRONMENT/DOMAIN inline at their top.

ENVIRONMENT="homelab"
DOMAIN="kubernerdes.com"
BASE_DOMAIN="${ENVIRONMENT}.${DOMAIN}"

# Admin and infra hosts
ADMIN_HOST="nuc-00"
DNS_HOST="nuc-00-01"
DNS2_HOST="nuc-00-02"
LB_HOST="nuc-00-03"

# Admin web/repo server
ADMIN_IP="10.0.0.10"
REPO_BASE="http://${ADMIN_IP}/${BASE_DOMAIN}"

# RKE2 cluster — Rancher Manager
RANCHER_VIP="10.0.0.210"
RANCHER_HOSTNAME="rancher.${BASE_DOMAIN}"

# RKE2 cluster — Observability
OBS_VIP="10.0.0.220"
OBS_HOSTNAME="observability.${BASE_DOMAIN}"

# RKE2 cluster — Apps
APPS_VIP="10.0.0.230"
APPS_HOSTNAME="apps.${BASE_DOMAIN}"

# Kubeconfig paths
KUBECONFIG_RANCHER="${HOME}/.kube/${ENVIRONMENT}-rancher.kubeconfig"
KUBECONFIG_OBS="${HOME}/.kube/${ENVIRONMENT}-observability.kubeconfig"
KUBECONFIG_APPS="${HOME}/.kube/${ENVIRONMENT}-apps.kubeconfig"
