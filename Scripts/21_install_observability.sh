# 21_install_observability.sh — Deploy SUSE Observability
#
# Not intended to be run as a script — cut and paste sections as needed.
# Run from the admin node (nuc-00) with KUBECONFIG pointing to the
# observability cluster.
#
# Prerequisites:
#   - 3 SL-Micro VMs deployed on Harvester (observability-01/02/03)
#   - RKE2 installed on all 3 VMs (Scripts/install_RKE2.sh — observability case)
#   - KUBECONFIG saved as ~/.kube/${ENVIRONMENT}-observability.kubeconfig
#   - O11Y_LICENSE env var set (SUSE Observability license key)
#   - Internet access from cluster nodes (pulls from public helm repo)
#
# Reference:
#   https://docs.stackstate.com/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

RANCHER_URL="https://${RANCHER_HOSTNAME}"
O11Y_URL="https://${OBS_HOSTNAME}"

export KUBECONFIG="${KUBECONFIG_OBS}"
kubectl get nodes

# ---------------------------------------------------------------------------
# cert-manager (required by Observability)
# ---------------------------------------------------------------------------
CERTMGR_VERSION="v1.18.0"

helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERTMGR_VERSION}" \
  --set crds.enabled=true

kubectl -n cert-manager rollout status deploy/cert-manager

# ---------------------------------------------------------------------------
# SUSE Observability — from public helm repo
# ---------------------------------------------------------------------------
[ -z "${O11Y_LICENSE:-}" ] && { echo "ERROR: O11Y_LICENSE is not set."; exit 1; }

helm repo add suse-observability https://charts.rancher.com/server-charts/prime/suse-observability
helm repo update

WORK_DIR=~/observability-install
mkdir -p "${WORK_DIR}" && cd "${WORK_DIR}"

# Generate values files from the Observability chart template
export VALUES_DIR="${WORK_DIR}"
helm template \
  --set license="${O11Y_LICENSE}" \
  --set rancherUrl="${RANCHER_URL}" \
  --set baseUrl="${O11Y_URL}" \
  --set sizing.profile='10-nonha' \
  suse-observability-values \
  suse-observability/suse-observability-values \
  --output-dir "${VALUES_DIR}"

# Install Observability
helm upgrade --install suse-observability \
  suse-observability/suse-observability \
  --namespace suse-observability \
  --create-namespace \
  --values "${VALUES_DIR}/suse-observability-values/templates/baseConfig_values.yaml" \
  --values "${VALUES_DIR}/suse-observability-values/templates/sizing_values.yaml" \
  --values "${VALUES_DIR}/suse-observability-values/templates/affinity_values.yaml"

echo "NOTE: Observability takes 15-20 minutes to fully stabilize."
kubectl get pods -n suse-observability -w

# ---------------------------------------------------------------------------
# Ingress (RKE2 uses nginx by default)
# ---------------------------------------------------------------------------
cat << EOF > "${WORK_DIR}/suse-observability-ingress.yaml"
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
kubectl apply -f "${WORK_DIR}/suse-observability-ingress.yaml"

# ---------------------------------------------------------------------------
# Retrieve admin password
# ---------------------------------------------------------------------------
echo "Observability UI : ${O11Y_URL}"
grep 'admin.*password' "$(find ${VALUES_DIR} -name baseConfig_values.yaml)" || true

exit 0
