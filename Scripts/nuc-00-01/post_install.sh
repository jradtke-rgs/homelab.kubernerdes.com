#!/bin/bash

# nuc-00-01 post_install.sh — Infra VM: DNS, DHCP, TFTP/PXE
#
# Run as the initial user (mansible) after a fresh OpenSUSE Leap 15.6 install.
# Intended for cut-and-paste execution.
#
# Services installed:
#   BIND   — authoritative DNS for ${BASE_DOMAIN}
#   DHCP   — ISC dhcpd with iPXE boot support for Harvester nodes
#   TFTP   — serves ipxe.efi for initial UEFI PXE handoff
#   kubectl — for cluster management from the infra node
#
# Config files are pulled from the admin node web root during install.
# Configs live in Files/nuc-00-01/ in this repo and are served via Apache.

# Inline environment config — this script runs before env.sh is available
ENVIRONMENT="${ENVIRONMENT:-community}"
DOMAIN="${DOMAIN:-kubernerdes.com}"
BASE_DOMAIN="${BASE_DOMAIN:-${ENVIRONMENT}.${DOMAIN}}"

case "${ENVIRONMENT}" in
  enclave)   IP_PREFIX="10.10.12" ;;
  carbide)   IP_PREFIX="10.10.13" ;;
  community) IP_PREFIX="10.10.14" ;;
  *) echo "ERROR: Unknown ENVIRONMENT '${ENVIRONMENT}'" >&2; exit 1 ;;
esac

REPO_BASE="http://${IP_PREFIX}.10/${BASE_DOMAIN}"
echo "# NOTE: using ${REPO_BASE} to pull bits"
curl -fsSL "${REPO_BASE}/README.md" | head -5

# ---------------------------------------------------------------------------
# Base packages
# ---------------------------------------------------------------------------
sudo zypper --non-interactive install sudo vim wget curl
MYUSER=$(whoami)
echo "${MYUSER} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/${MYUSER}-nopasswd-all

# ---------------------------------------------------------------------------
# DNS + DHCP pattern (BIND + ISC dhcpd)
# ---------------------------------------------------------------------------
sudo zypper --non-interactive install -t pattern dhcp_dns_server
sudo zypper --non-interactive install bind-utils

# ---------------------------------------------------------------------------
# TFTP + iPXE EFI binary (nuc-00-01 only — nuc-00-02 is DNS secondary)
# ---------------------------------------------------------------------------
case $(uname -n) in
  nuc-00-01)
    sudo zypper --non-interactive install tftp
    sudo mkdir -p /srv/tftpboot
    sudo wget -O /srv/tftpboot/ipxe.efi https://boot.netboot.xyz/ipxe/netboot.xyz.efi
  ;;
esac

# ---------------------------------------------------------------------------
# BIND configuration
# Pull named.conf and zone files from the admin node web root.
# Files are envsubst-processed templates from Files/nuc-00-01/etc/ in the repo.
# ---------------------------------------------------------------------------
sudo cp /etc/named.conf /etc/named.conf.$(date +%F)
sudo curl -fsSL -o /etc/named.conf "${REPO_BASE}/Files/nuc-00-01/etc/named.conf"

sudo mkdir -p /var/lib/named/master /var/lib/named/slave /var/lib/named/dyn
case $(uname -n) in
  nuc-00-01)
    for ZONE_FILE in \
      db.${BASE_DOMAIN} \
      db-${IP_PREFIX##*.}.${IP_PREFIX%.*}.in-addr.arpa
    do
      sudo curl -fsSL \
        -o /var/lib/named/master/${ZONE_FILE} \
        "${REPO_BASE}/Files/nuc-00-01/var/lib/named/master/${ZONE_FILE}"
    done
  ;;
esac

sudo systemctl enable named --now
sudo systemctl status named
host -l "${BASE_DOMAIN}"

# ---------------------------------------------------------------------------
# DHCP
# ---------------------------------------------------------------------------
case $(uname -n) in
  nuc-00-01)
    sudo cp /etc/dhcpd.conf /etc/dhcpd.conf.$(date +%F)
    sudo curl -fsSL -o /etc/dhcpd.conf "${REPO_BASE}/Files/nuc-00-01/etc/dhcpd.conf"
    sudo mkdir -p /etc/dhcpd.d/
    sudo curl -fsSL -o /etc/dhcpd.d/dhcpd-hosts.conf \
      "${REPO_BASE}/Files/nuc-00-01/etc/dhcpd.d/dhcpd-hosts.conf"

    sudo sed -i -e 's/DHCPD_INTERFACE=""/DHCPD_INTERFACE="eth0"/g' /etc/sysconfig/dhcpd

    sudo mkdir -p /etc/systemd/system/dhcpd.service.d
    printf '[Unit]\nRequires=network-online.target\nAfter=network-online.target\n' \
      | sudo tee /etc/systemd/system/dhcpd.service.d/override.conf
    sudo systemctl daemon-reload
    sudo systemctl enable dhcpd --now
    sudo systemctl status dhcpd
  ;;
esac

# ---------------------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------------------
for PORT in 53 80 443; do sudo firewall-cmd --permanent --zone=public --add-port=${PORT}/tcp; done
for PORT in 53 67 68 69 4011; do sudo firewall-cmd --permanent --zone=public --add-port=${PORT}/udp; done
for SVC in http https dns dhcp tftp; do sudo firewall-cmd --permanent --zone=public --add-service=${SVC}; done
sudo firewall-cmd --reload
sudo firewall-cmd --list-all

# ---------------------------------------------------------------------------
# kubectl
# ---------------------------------------------------------------------------
sudo tee /etc/zypp/repos.d/kubernetes.repo << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/repomd.xml.key
EOF
sudo zypper refresh
sudo zypper --non-interactive install kubectl

sudo zypper --non-interactive install ansible

exit 0
