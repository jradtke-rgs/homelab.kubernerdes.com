#!/bin/bash
#
# Deploy miscellaneous applications to the homelab applications cluster
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

KUBECONFIG="${KUBECONFIG:-${KUBECONFIG_APPS}}"
export KUBECONFIG

APPS_ENV="apps.${ENVIRONMENT}"

##############################################################################
# HexGL — futuristic WebGL racing game
##############################################################################

echo "=== Deploying HexGL ==="

HEXGL_TMP="$(mktemp -d)"
trap 'rm -rf "$HEXGL_TMP"' EXIT

echo "Cloning HexGL repo..."
git clone --depth=1 https://github.com/jradtke-rgs/HexGL "$HEXGL_TMP"

mkdir -p "$HEXGL_TMP/k8s/overlays/homelab"
cat > "$HEXGL_TMP/k8s/overlays/homelab/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: hexgl

resources:
  - ../../base

patches:
  - target:
      kind: Ingress
      name: hexgl
    patch: |
      - op: replace
        path: /spec/rules/0/host
        value: hexgl.${APPS_ENV}.${DOMAIN}

images:
  - name: hexgl
    newName: docker.io/cloudxabide/hexgl
    newTag: latest
EOF

bash "$HEXGL_TMP/scripts/deploy.sh" -k "$KUBECONFIG" -o homelab

##############################################################################
# chell-test — SUSE Security test workload (curl + wget, periodic fastly probe)
##############################################################################

echo "=== Deploying chell-test ==="

kubectl apply -f - <<'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: aperture-sci
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chell-test
  namespace: aperture-sci
  labels:
    app: chell-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chell-test
  template:
    metadata:
      labels:
        app: chell-test
    spec:
      containers:
        - name: chell-test
          image: nicolaka/netshoot
          command: ["/bin/sh", "-c"]
          args:
            - |
              while true; do
                curl -svo /dev/null https://www.fastly.com 2>&1 | grep subjectAltName
                sleep 5
              done
EOF

echo "chell-test deployed to namespace aperture-sci"
echo "be sure to remove/delete later"
echo "kubectl delete namespace aperture-sci"
