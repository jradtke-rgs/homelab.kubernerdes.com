#!/bin/bash
set -euo pipefail

# 02_setup_vault.sh — Install HashiCorp Vault as the homelab root CA on nuc-00
#
# Run ONCE as root on nuc-00.  Idempotent — safe to re-run.
# Supersedes 02_setup_ca.sh; Vault's PKI engine replaces the static openssl CA.
#
# License: HashiCorp BUSL 1.1 — free for personal/non-commercial homelab use.
#
# What this does:
#   1. Downloads and installs the Vault binary (VAULT_VERSION)
#   2. Creates vault system user, config, and systemd unit
#   3. Starts Vault, initializes it (one-time), unseals with 3 of 5 keys
#   4. Enables the PKI secrets engine as root CA for kubernerdes.com
#   5. Creates server and client cert issuance roles
#   6. Trusts the root CA on nuc-00 system trust store
#
# Init credentials (unseal keys + root token) are saved to VAULT_INIT_FILE.
# BACK THIS FILE UP — the unseal keys cannot be recovered if lost.
#
# This script is homelab-level infrastructure (not per-environment).
# It intentionally does NOT source env.sh — Vault serves all environments.
#
# Sign a cert manually after setup:
#   VAULT_TOKEN=$(jq -r .root_token /root/vault-init.json)
#   vault write pki/issue/homelab-server common_name=rancher.prime.kubernerdes.com
#
# Distribute root CA to a cluster node:
#   scp /etc/ssl/homelab-root-ca.crt root@<node>:/etc/pki/trust/anchors/homelab-root-ca.crt
#   ssh root@<node> update-ca-certificates
#
# cert-manager ClusterIssuer (after RKE2/Rancher up):
#   Auth endpoint: ${VAULT_ADDR}/v1/pki/sign/homelab-server
#   Use Vault token auth or the Kubernetes auth method

# ---------------------------------------------------------------------------
# Configuration — override by exporting before running
# ---------------------------------------------------------------------------

# Verify the version at https://releases.hashicorp.com/vault/ before running
VAULT_VERSION="${VAULT_VERSION:-1.18.4}"
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_DATA_DIR="${VAULT_DATA_DIR:-/opt/vault/data}"
VAULT_CONFIG_DIR="${VAULT_CONFIG_DIR:-/etc/vault.d}"
VAULT_LOG_DIR="${VAULT_LOG_DIR:-/var/log/vault}"
VAULT_INIT_FILE="${VAULT_INIT_FILE:-/root/vault-init.json}"

DOMAIN="${DOMAIN:-kubernerdes.com}"
VAULT_PKI_TTL="${VAULT_PKI_TTL:-87600h}"          # root CA validity: 10 years
VAULT_CERT_MAX_TTL="${VAULT_CERT_MAX_TTL:-8760h}" # issued cert maximum: 1 year
VAULT_CERT_TTL="${VAULT_CERT_TTL:-720h}"          # issued cert default: 30 days

export VAULT_ADDR

ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64)  VAULT_ARCH="amd64" ;;
  aarch64) VAULT_ARCH="arm64" ;;
  *)       echo "ERROR: unsupported arch ${ARCH}" >&2; exit 1 ;;
esac

VAULT_ZIP="vault_${VAULT_VERSION}_linux_${VAULT_ARCH}.zip"
VAULT_URL="https://releases.hashicorp.com/vault/${VAULT_VERSION}/${VAULT_ZIP}"

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Must run as root." >&2
  exit 1
fi

for cmd in curl unzip jq openssl; do
  command -v "${cmd}" >/dev/null || { echo "ERROR: ${cmd} is required but not installed." >&2; exit 1; }
done

# ---------------------------------------------------------------------------
# Step 1 — Install Vault binary
# ---------------------------------------------------------------------------
INSTALLED_VERSION=""
if command -v vault >/dev/null 2>&1; then
  INSTALLED_VERSION=$(vault version 2>&1 | awk '{print $2}' | tr -d 'v')
fi

if [[ "${INSTALLED_VERSION}" == "${VAULT_VERSION}" ]]; then
  echo "==> Vault ${VAULT_VERSION} already installed."
else
  echo "==> Downloading Vault ${VAULT_VERSION} (${VAULT_ARCH})"
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  curl -fsSL -o "${TMP_DIR}/${VAULT_ZIP}" "${VAULT_URL}"
  unzip -o "${TMP_DIR}/${VAULT_ZIP}" -d "${TMP_DIR}"
  install -o root -g root -m 755 "${TMP_DIR}/vault" /usr/local/bin/vault
  echo "    Installed: $(vault version)"
fi

# Allow vault to mlock memory without root (prevents secrets from swapping to disk)
setcap cap_ipc_lock=+ep /usr/local/bin/vault

# ---------------------------------------------------------------------------
# Step 2 — System user, directories, config
# ---------------------------------------------------------------------------
if ! id vault &>/dev/null; then
  echo "==> Creating vault system user"
  useradd --system --home "${VAULT_DATA_DIR}" --shell /sbin/nologin vault
fi

mkdir -p "${VAULT_DATA_DIR}" "${VAULT_CONFIG_DIR}" "${VAULT_LOG_DIR}"
chown -R vault:vault "${VAULT_DATA_DIR}" "${VAULT_LOG_DIR}"
chmod 750 "${VAULT_DATA_DIR}"

if [[ ! -f "${VAULT_CONFIG_DIR}/vault.hcl" ]]; then
  echo "==> Writing ${VAULT_CONFIG_DIR}/vault.hcl"
  cat > "${VAULT_CONFIG_DIR}/vault.hcl" << EOF
ui            = true
disable_mlock = false

storage "file" {
  path = "${VAULT_DATA_DIR}"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "${VAULT_ADDR}"
EOF
  chown root:vault "${VAULT_CONFIG_DIR}/vault.hcl"
  chmod 640 "${VAULT_CONFIG_DIR}/vault.hcl"
fi

# ---------------------------------------------------------------------------
# Step 3 — Systemd unit
# ---------------------------------------------------------------------------
if [[ ! -f /etc/systemd/system/vault.service ]]; then
  echo "==> Installing vault.service"
  cat > /etc/systemd/system/vault.service << 'UNIT'
[Unit]
Description=HashiCorp Vault
Documentation=https://developer.hashicorp.com/vault/docs
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl

[Service]
Type=notify
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
fi

systemctl enable --now vault
echo "==> Waiting for Vault API to be ready..."
for _ in $(seq 1 30); do
  if vault status > /dev/null 2>&1 || vault status 2>&1 | grep -qE "Initialized|Sealed"; then
    break
  fi
  sleep 1
done

# ---------------------------------------------------------------------------
# Step 4 — Initialize Vault (one-time)
# ---------------------------------------------------------------------------
VAULT_INITIALIZED=$(vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")

if [[ "${VAULT_INITIALIZED}" == "false" ]]; then
  echo "==> Initializing Vault (5 key shares, threshold 3)"
  vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json > "${VAULT_INIT_FILE}"
  chmod 600 "${VAULT_INIT_FILE}"
  echo "    Init credentials saved to ${VAULT_INIT_FILE}"
  echo "    WARNING: Back up ${VAULT_INIT_FILE} — these keys cannot be recovered!"
elif [[ ! -f "${VAULT_INIT_FILE}" ]]; then
  echo "ERROR: Vault is already initialized but ${VAULT_INIT_FILE} not found." >&2
  echo "       Restore the init file to ${VAULT_INIT_FILE} and re-run." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 5 — Unseal Vault
# ---------------------------------------------------------------------------
VAULT_SEALED=$(vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")

if [[ "${VAULT_SEALED}" == "true" ]]; then
  echo "==> Unsealing Vault (applying 3 of 5 keys)"
  for i in 0 1 2; do
    UNSEAL_KEY=$(jq -r ".unseal_keys_b64[${i}]" "${VAULT_INIT_FILE}")
    vault operator unseal "${UNSEAL_KEY}" > /dev/null
  done
  echo "    Vault unsealed."
fi

export VAULT_TOKEN
VAULT_TOKEN=$(jq -r '.root_token' "${VAULT_INIT_FILE}")

# ---------------------------------------------------------------------------
# Step 6 — Enable PKI secrets engine (root CA)
# ---------------------------------------------------------------------------
PKI_ENABLED=$(vault secrets list -format=json 2>/dev/null | jq -r '."pki/" // "false"')

if [[ "${PKI_ENABLED}" == "false" ]]; then
  echo "==> Enabling PKI secrets engine"
  vault secrets enable \
    -path=pki \
    -max-lease-ttl="${VAULT_PKI_TTL}" \
    pki

  echo "==> Generating root CA for ${DOMAIN}"
  vault write -format=json pki/root/generate/internal \
    common_name="${DOMAIN} Root CA" \
    issuer_name="homelab-root" \
    ttl="${VAULT_PKI_TTL}" \
    key_bits=4096 \
    | jq -r '.data.certificate' > /etc/ssl/homelab-root-ca.crt
  chmod 644 /etc/ssl/homelab-root-ca.crt

  echo "==> Configuring CRL and issuing certificate URLs"
  vault write pki/config/urls \
    issuing_certificates="${VAULT_ADDR}/v1/pki/ca" \
    crl_distribution_points="${VAULT_ADDR}/v1/pki/crl"

  echo "==> Creating role: homelab-server"
  vault write pki/roles/homelab-server \
    allowed_domains="${DOMAIN}" \
    allow_subdomains=true \
    allow_glob_domains=false \
    enforce_hostnames=true \
    max_ttl="${VAULT_CERT_MAX_TTL}" \
    ttl="${VAULT_CERT_TTL}" \
    key_type=rsa \
    key_bits=4096 \
    server_flag=true \
    client_flag=false

  echo "==> Creating role: homelab-client"
  vault write pki/roles/homelab-client \
    allowed_domains="${DOMAIN}" \
    allow_subdomains=true \
    allow_glob_domains=false \
    enforce_hostnames=true \
    max_ttl="${VAULT_CERT_MAX_TTL}" \
    ttl="${VAULT_CERT_TTL}" \
    key_type=rsa \
    key_bits=4096 \
    server_flag=false \
    client_flag=true

  echo
  echo "    Root CA cert:  /etc/ssl/homelab-root-ca.crt"
  echo "    Subject:       $(openssl x509 -in /etc/ssl/homelab-root-ca.crt -noout -subject)"
  echo "    Expires:       $(openssl x509 -in /etc/ssl/homelab-root-ca.crt -noout -enddate)"
else
  echo "==> PKI secrets engine already configured."
fi

# ---------------------------------------------------------------------------
# Step 7 — Trust root CA on nuc-00 system trust store
# ---------------------------------------------------------------------------
if [[ ! -f /etc/pki/trust/anchors/homelab-root-ca.crt ]]; then
  echo "==> Trusting root CA on nuc-00"
  cp /etc/ssl/homelab-root-ca.crt /etc/pki/trust/anchors/homelab-root-ca.crt
  update-ca-certificates
fi

if systemctl is-active --quiet docker 2>/dev/null; then
  echo "==> Restarting Docker to pick up new CA"
  systemctl restart docker
fi

# ---------------------------------------------------------------------------
# Step 8 — Publish root CA via Apache for node bootstrap (install_RKE2.sh)
# ---------------------------------------------------------------------------
APACHE_ROOT="/srv/www/htdocs"
if [[ -d "${APACHE_ROOT}" ]]; then
  cp /etc/ssl/homelab-root-ca.crt "${APACHE_ROOT}/homelab-root-ca.crt"
  chmod 644 "${APACHE_ROOT}/homelab-root-ca.crt"
  echo "==> Root CA published at http://<ADMIN_IP>/homelab-root-ca.crt"
else
  echo "    INFO: Apache web root ${APACHE_ROOT} not found — CA not published via HTTP."
  echo "         Use 03_distribute_ca.sh to push the CA to nodes manually."
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
echo "==> Vault CA setup complete."
echo
echo "    Vault UI:      ${VAULT_ADDR}/ui"
echo "    Root CA cert:  /etc/ssl/homelab-root-ca.crt"
echo "    Init file:     ${VAULT_INIT_FILE}  (chmod 600 — back this up!)"
echo
echo "    Distribute root CA to all existing nodes:"
echo "      bash Scripts/03_distribute_ca.sh"
echo
echo "    Issue a cert manually:"
echo "      VAULT_TOKEN=\$(jq -r .root_token ${VAULT_INIT_FILE})"
echo "      vault write pki/issue/homelab-server common_name=rancher.prime.${DOMAIN}"
echo
echo "    cert-manager ClusterIssuer is created by 10_install_rancher_manager.sh"
echo
