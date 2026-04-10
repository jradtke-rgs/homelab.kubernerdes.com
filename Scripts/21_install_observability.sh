#!/bin/bash
set -euo pipefail

# 21_install_observability.sh — Deploy SUSE Observability
#
# Run from nuc-00 with KUBECONFIG pointing to the observability cluster.
#
# Prerequisites:
#   - 3 SL-Micro VMs deployed on Harvester (observability-01/02/03)
#   - RKE2 installed on all 3 (Scripts/install_RKE2.sh — observability case)
#   - KUBECONFIG saved as ${KUBECONFIG_OBS}
#   - O11Y_LICENSE environment variable set (SUSE Observability license key)
#     export O11Y_LICENSE=<your-license-key>
#
# Reference:
#   https://docs.stackstate.com/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

[ -z "${O11Y_LICENSE:-}" ] && { echo "ERROR: O11Y_LICENSE is not set."; exit 1; }

export KUBECONFIG="${KUBECONFIG_OBS}"
echo "==> Observability cluster nodes:"
kubectl get nodes

# ---------------------------------------------------------------------------
# cert-manager (required by Observability)
# ---------------------------------------------------------------------------
echo "==> Installing cert-manager ${CERTMGR_VERSION}..."
helm upgrade --install cert-manager "${CERT_MANAGER_SOURCE}" \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERTMGR_VERSION}" \
  --set crds.enabled=true

kubectl -n cert-manager rollout status deploy/cert-manager --timeout=120s

# ---------------------------------------------------------------------------
# SUSE Observability
# ---------------------------------------------------------------------------
echo "==> Adding SUSE Observability helm repo (${OBS_CHART_REPO})..."
helm repo add suse-observability "${OBS_CHART_REPO}" 2>/dev/null || true
helm repo update

WORK_DIR=~/observability-install
mkdir -p "${WORK_DIR}" && cd "${WORK_DIR}"

echo "==> Generating Observability values files..."
export VALUES_DIR="${WORK_DIR}"
helm template \
  --set license="${O11Y_LICENSE}" \
  --set rancherUrl="https://${RANCHER_HOSTNAME}" \
  --set baseUrl="https://${OBS_HOSTNAME}" \
  --set sizing.profile='10-nonha' \
  suse-observability-values \
  suse-observability/suse-observability-values \
  --output-dir "${VALUES_DIR}"

echo "==> Installing SUSE Observability..."
helm upgrade --install suse-observability \
  suse-observability/suse-observability \
  --namespace suse-observability \
  --create-namespace \
  --values "${VALUES_DIR}/suse-observability-values/templates/baseConfig_values.yaml" \
  --values "${VALUES_DIR}/suse-observability-values/templates/sizing_values.yaml" \
  --values "${VALUES_DIR}/suse-observability-values/templates/affinity_values.yaml"

echo "NOTE: Observability takes 15-20 minutes to fully stabilize."

# ---------------------------------------------------------------------------
# Ingress
# ---------------------------------------------------------------------------
kubectl apply -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: suse-observability-ui
  namespace: suse-observability
spec:
  ingressClassName: nginx
  rules:
  - host: ${OBS_HOSTNAME}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: suse-observability-router
            port:
              number: 8080
  tls:
  - hosts:
    - ${OBS_HOSTNAME}
EOF

# ---------------------------------------------------------------------------
# Access info
# ---------------------------------------------------------------------------
ADMIN_PASS=$(grep 'admin.*password' \
  "$(find ${VALUES_DIR} -name baseConfig_values.yaml 2>/dev/null | head -1)" \
  2>/dev/null || echo "(check values file in ${WORK_DIR})")

echo
echo "========================================"
echo " SUSE Observability deploying..."
echo " URL:      https://${OBS_HOSTNAME}"
echo " Password: ${ADMIN_PASS}"
echo "========================================"
echo
echo "Next step: Scripts/30_deploy_apps.sh"
