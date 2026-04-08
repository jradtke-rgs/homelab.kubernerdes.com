# 20_install_RGS_security.sh — Deploy SUSE Security (NeuVector) on the apps cluster
#
# Not intended to be run as a script — cut and paste sections as needed.
# Run from the admin node (nuc-00) with KUBECONFIG pointing to the
# apps cluster.
#
# Prerequisites:
#   - apps cluster deployed via Rancher Manager (3-node RKE2 on SL-Micro)
#   - KUBECONFIG saved as ~/.kube/${ENVIRONMENT}-apps.kubeconfig
#   - Internet access from cluster nodes (community install pulls from public registry)
#
# Chart version 2.8.11 = NeuVector appVersion 5.4.9
#
# Reference:
#   https://open-docs.neuvector.com/deploying/kubernetes
#   https://ranchermanager.docs.rancher.com/integrations-in-rancher/neuvector

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

NEUVECTOR_VERSION="5.4.9"
NEUVECTOR_CHART_VERSION="2.8.11"   # chart version for NeuVector 5.4.9
RANCHER_URL="https://${RANCHER_HOSTNAME}"

export KUBECONFIG="${KUBECONFIG_APPS}"
if ! kubectl get nodes &>/dev/null; then
  echo "ERROR: cannot reach cluster via $KUBECONFIG — exiting" >&2
  exit 1
fi
kubectl get nodes

# ---------------------------------------------------------------------------
# NeuVector namespace
# ---------------------------------------------------------------------------
kubectl create namespace cattle-neuvector-system

# ---------------------------------------------------------------------------
# Install NeuVector from public helm chart (neuvector/core)
# ---------------------------------------------------------------------------
helm repo add neuvector https://neuvector.github.io/neuvector-helm/
helm repo update

helm upgrade --install neuvector neuvector/core \
  --version "${NEUVECTOR_CHART_VERSION}" \
  --namespace cattle-neuvector-system \
  --set manager.svc.type=ClusterIP \
  --set controller.replicas=3 \
  --set cve.scanner.replicas=2 \
  --set controller.pvc.enabled=false \
  --set k3s.enabled=false \
  --set manager.ingress.enabled=false \
  --set global.cattle.url="${RANCHER_URL}"

kubectl -n cattle-neuvector-system rollout status deploy/neuvector-manager-pod

# ---------------------------------------------------------------------------
# Ingress for NeuVector Manager UI
# ---------------------------------------------------------------------------
cat << 'EOF' > /tmp/neuvector-ingress.yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: neuvector-manager
  namespace: cattle-neuvector-system
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
    - host: neuvector.applications.${BASE_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: neuvector-service-webui
                port:
                  number: 8443
  tls:
    - hosts:
        - neuvector.applications.${BASE_DOMAIN}
EOF
kubectl apply -f /tmp/neuvector-ingress.yaml
kubectl get ingress -n cattle-neuvector-system

# ---------------------------------------------------------------------------
# Retrieve bootstrap password
# ---------------------------------------------------------------------------
echo "NeuVector UI: https://neuvector.applications.${BASE_DOMAIN}"
echo "Bootstrap password: $(kubectl get secret \
  --namespace cattle-neuvector-system neuvector-bootstrap-secret \
  -o go-template='{{ .data.bootstrapPassword|base64decode}}{{ "\n" }}' 2>/dev/null \
  || echo '(not yet available — check after pods are fully ready)')"

exit 0
