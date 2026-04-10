#!/bin/bash
set -euo pipefail

# 10_install_rancher_manager.sh — Deploy cert-manager + Rancher Manager Server
#
# Run from nuc-00 after RKE2 is up on all 3 rancher nodes.
#
# Prerequisites:
#   - RKE2 installed on rancher-01/02/03 (Scripts/install_RKE2.sh)
#   - kubectl and helm available on nuc-00
#   - SSH access to rancher-01 via sles@rancher-01
#   - For Carbide/Enclave: run the appropriate module first
#       Carbide: Scripts/modules/carbide/registry_auth.sh
#       Enclave: Scripts/modules/enclave/harbor_setup.sh
#
# Chart sources are environment-controlled via env.d/:
#   community → rancher-latest (releases.rancher.com)
#   carbide   → rancher-prime  (charts.rancher.com)
#   enclave   → local Harbor
#
# Reference:
#   https://ranchermanager.docs.rancher.com/getting-started/quick-start-guides/deploy-rancher-manager/helm-cli

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

KUBECONFIG_PATH="${KUBECONFIG_RANCHER}"

# ---------------------------------------------------------------------------
# Retrieve kubeconfig from rancher-01
# ---------------------------------------------------------------------------
echo "==> Fetching kubeconfig from rancher-01 (${RANCHER_NODE_01})..."
mkdir -p "${HOME}/.kube"
scp ${SSH_OPTS} sles@${RANCHER_NODE_01}:.kube/config "${KUBECONFIG_PATH}"
sed -i -e "s/127.0.0.1/${RANCHER_VIP}/g" "${KUBECONFIG_PATH}"
export KUBECONFIG="${KUBECONFIG_PATH}"

echo "==> Cluster nodes:"
kubectl get nodes

# ---------------------------------------------------------------------------
# cert-manager
# ---------------------------------------------------------------------------
echo "==> Installing cert-manager ${CERTMGR_VERSION}..."
helm upgrade --install cert-manager "${CERT_MANAGER_SOURCE}" \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERTMGR_VERSION}" \
  --set crds.enabled=true

kubectl -n cert-manager rollout status deploy/cert-manager --timeout=120s

# ---------------------------------------------------------------------------
# Rancher Manager
# ---------------------------------------------------------------------------
echo "==> Adding Rancher helm repo (${RANCHER_CHART_REPO})..."
helm repo add rancher-latest "${RANCHER_CHART_REPO}" 2>/dev/null || true
helm repo update

echo "==> Installing Rancher ${RANCHER_VERSION}..."
helm upgrade --install rancher "${RANCHER_CHART_NAME}" \
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
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{ "\n" }}' 2>/dev/null \
  || echo "ChangeMe-RancherBootstrap")

echo
echo "========================================"
echo " Rancher Manager is up!"
echo " URL:      https://${RANCHER_HOSTNAME}/dashboard/?setup=${BOOTSTRAP_PASSWORD}"
echo " Password: ${BOOTSTRAP_PASSWORD}"
echo "========================================"
echo
echo "Next step: Scripts/20_install_security.sh"
