# This "script" was not intended to be run as a script, and instead cut-and-paste the pieces (hence no #!/bin/sh at the top ;-)
# Reference: https://open-docs.neuvector.com/deploying/kubernetes
# Reference: https://ranchermanager.docs.rancher.com/integrations-in-rancher/neuvector

# SUSE Security (NeuVector) on the "applications" cluster
# SSH:   ssh -i ~/.ssh/id_rsa-homelab sles@<IP>

# Configure correct K8s cluster
ENVIRONMENT="${ENVIRONMENT:-homelab}"
DOMAIN="${DOMAIN:-kubernerdes.com}"
BASE_DOMAIN="${BASE_DOMAIN:-${ENVIRONMENT}.${DOMAIN}}"
export KUBECONFIG="${KUBECONFIG:-~/.kube/${ENVIRONMENT}-applications.kubeconfig}"

#######################################
# CVE Comparison: Old vs New image tags
#######################################
# Deploy two pods with different Rancher image versions to compare
# CVE counts side-by-side in NeuVector's vulnerability scanner.

RANCHER_OLD_VERSION="v2.8.0"    # older version — more CVEs expected
RANCHER_NEW_VERSION="v2.13.3"   # current version — fewer CVEs expected

# #########################################
## OLDER IMAGE (more CVEs)
# #########################################
NAMESPACE=cvet-rancher-old
kubectl create namespace ${NAMESPACE}

cat << EOF | kubectl apply -f -
---
apiVersion: v1
kind: Pod
metadata:
  name: rancher-old
  namespace: ${NAMESPACE}
  labels:
    app: rancher
    source: community-old
spec:
  containers:
  - name: rancher
    image: docker.io/rancher/rancher:${RANCHER_OLD_VERSION}
    command: ["sleep", "infinity"]
EOF

kubectl wait --for=condition=Ready pod/rancher-old -n ${NAMESPACE} --timeout=120s
kubectl get pods -n ${NAMESPACE}

# #########################################
## NEWER IMAGE (fewer CVEs)
# #########################################
NAMESPACE=cvet-rancher-new
kubectl create namespace ${NAMESPACE}

cat << EOF | kubectl apply -f -
---
apiVersion: v1
kind: Pod
metadata:
  name: rancher-new
  namespace: ${NAMESPACE}
  labels:
    app: rancher
    source: community-new
spec:
  containers:
  - name: rancher
    image: docker.io/rancher/rancher:${RANCHER_NEW_VERSION}
    command: ["sleep", "infinity"]
EOF

kubectl wait --for=condition=Ready pod/rancher-new -n ${NAMESPACE} --timeout=120s
kubectl get pods -n ${NAMESPACE}

# #########################################
## MICROSERVICES DEMO APP (Google Online Boutique)
## Reference: https://github.com/jradtke-rgs/microservices-demo
## A realistic multi-service app — good for NeuVector network policy/CVE demos
# #########################################
NAMESPACE=microservices-demo
kubectl create namespace ${NAMESPACE}

kubectl apply -n ${NAMESPACE} -f https://raw.githubusercontent.com/jradtke-rgs/microservices-demo/main/release/kubernetes-manifests.yaml

kubectl wait --for=condition=Available deployment --all -n ${NAMESPACE} --timeout=300s
kubectl get pods -n ${NAMESPACE}

# Expose the frontend via Ingress
cat << EOF | kubectl apply -f -
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: online-boutique
  namespace: ${NAMESPACE}
spec:
  rules:
  - host: online-boutique.applications.${BASE_DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF

# #########################################
## CLEANUP (when done with the comparison)
# #########################################
# kubectl delete namespace cvet-rancher-old cvet-rancher-new microservices-demo

exit 0
