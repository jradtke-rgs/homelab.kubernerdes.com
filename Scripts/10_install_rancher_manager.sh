#!/bin/bash
set -euo pipefail

# 10_install_rancher_manager.sh — Deploy cert-manager + Rancher Manager Server
#
# Run from the admin node (nuc-00) after RKE2 is up on all 3 rancher nodes.
# Prerequisites:
#   - RKE2 installed on rancher-01/02/03 (Scripts/install_RKE2.sh)
#   - kubectl and helm available on this host
#   - SSH access to rancher-01 via sles@rancher-01
#
# Reference:
#   https://ranchermanager.docs.rancher.com/getting-started/quick-start-guides/deploy-rancher-manager/helm-cli

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

CERTMGR_VERSION="v1.19.2"
RANCHER_VERSION="2.13.3"
RKE2_VIP="${RANCHER_VIP}"
KUBECONFIG_PATH="${KUBECONFIG_RANCHER}"
SSH_KEY="${HOME}/.ssh/id_rsa-kubernerdes"
SSH_OPTS="-i ${SSH_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=10"

# ---------------------------------------------------------------------------
# Retrieve kubeconfig from rancher-01
# ---------------------------------------------------------------------------
echo "==> Fetching kubeconfig from rancher-01..."
mkdir -p "${HOME}/.kube"
scp ${SSH_OPTS} sles@${IP_PREFIX}.211:.kube/config "${KUBECONFIG_PATH}"
sed -i -e "s/127.0.0.1/${RKE2_VIP}/g" "${KUBECONFIG_PATH}"
export KUBECONFIG="${KUBECONFIG_PATH}"

echo "==> Cluster nodes:"
kubectl get nodes

# ---------------------------------------------------------------------------
# cert-manager
# ---------------------------------------------------------------------------
echo "==> Installing cert-manager ${CERTMGR_VERSION}..."
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERTMGR_VERSION}" \
  --set crds.enabled=true

kubectl -n cert-manager rollout status deploy/cert-manager --timeout=120s

# ---------------------------------------------------------------------------
# Rancher Manager
# ---------------------------------------------------------------------------
echo "==> Adding rancher-latest helm repo..."
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

echo "==> Installing Rancher ${RANCHER_VERSION}..."
helm upgrade --install rancher rancher-latest/rancher \
  --version "${RANCHER_VERSION}" \
  --namespace cattle-system \
  --create-namespace \
  --set hostname="${RANCHER_HOSTNAME}" \
  --set replicas=3 \
  --set bootstrapPassword=ChangeMe-RancherBootstrap

kubectl -n cattle-system rollout status deploy/rancher --timeout=300s

# ---------------------------------------------------------------------------
# Print access info
# ---------------------------------------------------------------------------
BOOTSTRAP_PASSWORD=$(kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{ "\n" }}')

echo
echo "========================================"
echo " Rancher Manager is up!"
echo " URL:      https://${RANCHER_HOSTNAME}/dashboard/?setup=${BOOTSTRAP_PASSWORD}"
echo " Password: ${BOOTSTRAP_PASSWORD}"
echo "========================================"
