#!/bin/bash
set -euo pipefail

# 80_compare_images.sh — Community vs Carbide image comparison via NeuVector
#
# This script intentionally references both community (public registry) AND
# Carbide (RGS registry) images side by side. This is the only script in the
# repo that mixes community and Carbide references by design.
#
# What this demonstrates:
#   1. Deploy the same application using a community image (Docker Hub)
#   2. Deploy the same application using the Carbide hardened image (RGS registry)
#   3. Observe the difference in CVE scan results in the NeuVector UI
#
# Prerequisites:
#   - Apps cluster running with NeuVector deployed (Scripts/20_install_security.sh)
#   - KUBECONFIG pointing to apps cluster
#   - For Carbide image: RGS registry credentials configured
#
# The comparison namespace is temporary — clean up when done:
#   kubectl delete namespace image-compare

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

export KUBECONFIG="${KUBECONFIG_APPS}"
if ! kubectl get nodes &>/dev/null; then
  echo "ERROR: cannot reach apps cluster via ${KUBECONFIG} — exiting" >&2
  exit 1
fi

kubectl create namespace image-compare 2>/dev/null || true

# ---------------------------------------------------------------------------
# Community image — pulled from Docker Hub
# ---------------------------------------------------------------------------
echo "==> Deploying community nginx image (Docker Hub)"
kubectl apply -f - <<'EOF'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-community
  namespace: image-compare
  labels:
    app: nginx-community
    image-source: community
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-community
  template:
    metadata:
      labels:
        app: nginx-community
        image-source: community
    spec:
      containers:
        - name: nginx
          image: docker.io/library/nginx:latest
          ports:
            - containerPort: 80
EOF

# ---------------------------------------------------------------------------
# Carbide image — pulled from RGS registry
# Note: this will fail gracefully if RGS credentials are not configured.
# ---------------------------------------------------------------------------
echo "==> Deploying Carbide nginx image (registry.rancher.com)"
kubectl apply -f - <<'EOF'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-carbide
  namespace: image-compare
  labels:
    app: nginx-carbide
    image-source: carbide
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-carbide
  template:
    metadata:
      labels:
        app: nginx-carbide
        image-source: carbide
    spec:
      containers:
        - name: nginx
          image: registry.rancher.com/rgs/nginx:latest
          ports:
            - containerPort: 80
EOF

echo
echo "==> Waiting for pods..."
kubectl -n image-compare rollout status deploy/nginx-community --timeout=120s
kubectl -n image-compare get pods -o wide

echo
echo "========================================"
echo " Image comparison deployed!"
echo
echo " 1. Open NeuVector:  https://neuvector.${APPS_HOSTNAME}"
echo " 2. Go to: Security Risks > Vulnerabilities"
echo " 3. Filter by namespace: image-compare"
echo " 4. Compare CVE counts between nginx-community and nginx-carbide"
echo
echo " Clean up when done:"
echo "   kubectl delete namespace image-compare"
echo "========================================"
