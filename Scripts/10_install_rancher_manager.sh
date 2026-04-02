# 10_install_rancher_manager.sh — Deploy RKE2 + Rancher Manager Server
#
# Not intended to be run as a script — cut and paste sections as needed.
# Run from the admin node (nuc-00) or any host with kubectl + helm access.
#
# Prerequisites:
#   - 3 SL-Micro VMs deployed on Harvester (rancher-01/02/03)
#   - RKE2 v1.34.x installed on all 3 VMs (see Scripts/install_RKE2.sh)
#   - KUBECONFIG for the rancher cluster copied to ~/.kube/homelab-rancher.kubeconfig
#   - Internet access from the cluster nodes (community install pulls from public registries)
#
# Reference:
#   https://ranchermanager.docs.rancher.com/getting-started/quick-start-guides/deploy-rancher-manager/helm-cli

# ---------------------------------------------------------------------------
# Deploy the 3 Rancher VMs on Harvester
# ---------------------------------------------------------------------------
# Create 3 VMs in Harvester UI (or via API):
#   - OS: SL-Micro 6.1 (ISO served by nuc-00 or downloaded directly)
#   - CPU: 4 vCPU, RAM: 8GB, Disk: 50GB
#   - Hostnames: rancher-01, rancher-02, rancher-03
#   - IPs: 10.0.0.211, .212, .213  (static, per DNS zone)
#
# Then run Scripts/install_RKE2.sh on each VM (see that script for details).

# ---------------------------------------------------------------------------
# Retrieve kubeconfig from rancher-01 after RKE2 is up
# ---------------------------------------------------------------------------
scp sles@rancher-01:.kube/config ~/.kube/homelab-rancher.kubeconfig
sed -i -e 's/127.0.0.1/10.0.0.210/g' ~/.kube/homelab-rancher.kubeconfig   # use VIP
export KUBECONFIG=~/.kube/homelab-rancher.kubeconfig
kubectl get nodes

# ---------------------------------------------------------------------------
# cert-manager — public OCI registry (quay.io/jetstack)
# NOTE: Rancher 2.13.x supports Kubernetes <= 1.34.x.
#       RKE2 must be pinned to v1.34.x (see install_RKE2.sh).
# ---------------------------------------------------------------------------
CERTMGR_VERSION="v1.19.2"
RANCHER_VERSION="2.13.3"        # NOTE: no leading 'v' for helm chart version
RANCHER_HOSTNAME="rancher.homelab.kubernerdes.com"

helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version ${CERTMGR_VERSION} \
  --set crds.enabled=true

kubectl -n cert-manager rollout status deploy/cert-manager

# ---------------------------------------------------------------------------
# Rancher Manager — community chart from releases.rancher.com
# ---------------------------------------------------------------------------
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

helm upgrade --install rancher rancher-latest/rancher \
  --version "${RANCHER_VERSION}" \
  --namespace cattle-system \
  --create-namespace \
  --set hostname="${RANCHER_HOSTNAME}" \
  --set replicas=3 \
  --set bootstrapPassword=ChangeMe-RancherBootstrap

kubectl -n cattle-system rollout status deploy/rancher

# ---------------------------------------------------------------------------
# Retrieve bootstrap URL
# ---------------------------------------------------------------------------
echo
echo "Rancher UI: https://${RANCHER_HOSTNAME}/dashboard/?setup=$(kubectl get secret \
  --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}')"

BOOTSTRAP_PASSWORD=$(kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{ "\n" }}')
echo "Bootstrap password: ${BOOTSTRAP_PASSWORD}"

exit 0
