#!/bin/bash
set -euo pipefail

# 02_setup_ca.sh — Generate the homelab root CA on nuc-00
#
# Run ONCE as root on nuc-00, before any service requiring TLS.
# Idempotent — exits cleanly if the CA already exists.
#
# What this does:
#   1. Generates an RSA 4096 root CA (10-year validity)
#   2. Stores it in /etc/ssl/${ENVIRONMENT}-ca/ (key is chmod 600)
#   3. Adds the root CA to the nuc-00 system trust store
#   4. Restarts Docker if running (picks up the new CA immediately)
#
# To sign a certificate for a new service:
#   openssl genrsa -out <service>.key 4096
#   openssl req -new -key <service>.key -out <service>.csr \
#     -subj "/CN=<hostname>/O=${ENVIRONMENT}/C=US"
#   openssl x509 -req -days 730 -in <service>.csr \
#     -CA /etc/ssl/${ENVIRONMENT}-ca/ca.crt \
#     -CAkey /etc/ssl/${ENVIRONMENT}-ca/ca.key -CAcreateserial \
#     -out <service>.crt \
#     -extfile <(printf "subjectAltName=DNS:<hostname>,IP:<ip>")
#
# Distribute the root CA cert to all nodes:
#   scp /etc/ssl/${ENVIRONMENT}-ca/ca.crt \
#     root@<node>:/etc/pki/trust/anchors/${ENVIRONMENT}-root-ca.crt
#   ssh root@<node> update-ca-certificates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

CA_DIR="/etc/ssl/${ENVIRONMENT}-ca"
CA_CN="${CA_CN:-${BASE_DOMAIN} Root CA}"
CA_VALIDITY_DAYS="${CA_VALIDITY_DAYS:-3650}"  # 10 years

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

# ---------------------------------------------------------------------------
# Idempotency check
# ---------------------------------------------------------------------------
if [[ -f "${CA_DIR}/ca.crt" && -f "${CA_DIR}/ca.key" ]]; then
  echo "==> Root CA already exists at ${CA_DIR} — nothing to do."
  echo "    Subject: $(openssl x509 -in "${CA_DIR}/ca.crt" -noout -subject)"
  echo "    Expires: $(openssl x509 -in "${CA_DIR}/ca.crt" -noout -enddate)"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 1 — Generate root CA
# ---------------------------------------------------------------------------
echo "==> Generating root CA for ${BASE_DOMAIN}"
mkdir -p "${CA_DIR}"
chmod 700 "${CA_DIR}"

openssl genrsa -out "${CA_DIR}/ca.key" 4096
chmod 600 "${CA_DIR}/ca.key"

openssl req -x509 -new -nodes \
  -key  "${CA_DIR}/ca.key" \
  -sha256 \
  -days "${CA_VALIDITY_DAYS}" \
  -out  "${CA_DIR}/ca.crt" \
  -subj "/CN=${CA_CN}/O=${ENVIRONMENT}/C=US" \
  -addext "basicConstraints=critical,CA:true" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

echo "    CA cert:    ${CA_DIR}/ca.crt"
echo "    CA key:     ${CA_DIR}/ca.key  (do not distribute)"
echo "    Subject:    $(openssl x509 -in "${CA_DIR}/ca.crt" -noout -subject)"
echo "    Expires:    $(openssl x509 -in "${CA_DIR}/ca.crt" -noout -enddate)"

# ---------------------------------------------------------------------------
# Step 2 — Trust on nuc-00
# ---------------------------------------------------------------------------
echo "==> Adding root CA to nuc-00 system trust store"
cp "${CA_DIR}/ca.crt" /etc/pki/trust/anchors/${ENVIRONMENT}-root-ca.crt
update-ca-certificates

# ---------------------------------------------------------------------------
# Step 3 — Restart Docker if running
# ---------------------------------------------------------------------------
if systemctl is-active --quiet docker 2>/dev/null; then
  echo "==> Restarting Docker to pick up new CA"
  systemctl restart docker
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
echo "==> Root CA setup complete."
echo
echo "    Distribute to all nodes before installing services:"
echo "      scp ${CA_DIR}/ca.crt root@<node>:/etc/pki/trust/anchors/${ENVIRONMENT}-root-ca.crt"
echo "      ssh root@<node> update-ca-certificates"
echo
echo "    cert-manager integration (after RKE2/Rancher is up):"
echo "      Create a CA ClusterIssuer using ${CA_DIR}/ca.crt and ${CA_DIR}/ca.key"
echo
