#!/usr/bin/env bash
# env.d/carbide.sh — Carbide environment variables
#
# Sourced automatically by env.sh when ENVIRONMENT=carbide.
# Do not source directly.
#
# Carbide = RGS software pulled from registry.rancher.com over the internet.
# Requires a valid RGS Carbide subscription and registry credentials.
# Run modules/carbide/registry_auth.sh before the main deployment sequence.

# ---------------------------------------------------------------------------
# Hardware (update MACs for Carbide physical nodes)
# ---------------------------------------------------------------------------
export NIC_NAME="enp86s0"
export NUC01_MAC=""   # TODO: set MAC for carbide nuc-01
export NUC02_MAC=""   # TODO: set MAC for carbide nuc-02
export NUC03_MAC=""   # TODO: set MAC for carbide nuc-03

# ---------------------------------------------------------------------------
# Software versions (RGS government-hardened builds)
# ---------------------------------------------------------------------------
export HARVESTER_VERSION="v1.7.1-amd64-govt.1"
export RKE2_VERSION="v1.34.4+rke2r2"
export RANCHER_VERSION="2.13.3"
export CERTMGR_VERSION="v1.19.2"
export NEUVECTOR_CHART_VERSION="2.8.11"
export NEUVECTOR_VERSION="5.4.9"

# ---------------------------------------------------------------------------
# Registry — RGS Carbide registry
# ---------------------------------------------------------------------------
export RGS_REGISTRY="registry.rancher.com"
export REGISTRY_MIRROR="${RGS_REGISTRY}"
# RGS_TOKEN must be set externally (e.g. export RGS_TOKEN=<your-token>)
# or via modules/carbide/registry_auth.sh before deployment

# ---------------------------------------------------------------------------
# Chart and image sources
# ---------------------------------------------------------------------------
export CERT_MANAGER_SOURCE="oci://quay.io/jetstack/charts/cert-manager"
export RANCHER_CHART_REPO="https://charts.rancher.com/server-charts/prime"
export RANCHER_CHART_NAME="rancher-prime/rancher"
export NEUVECTOR_CHART_REPO="https://neuvector.github.io/neuvector-helm/"
export NEUVECTOR_CHART_NAME="neuvector/core"
export OBS_CHART_REPO="https://charts.rancher.com/server-charts/prime/suse-observability"

# ---------------------------------------------------------------------------
# RKE2 install source
# ---------------------------------------------------------------------------
export RKE2_INSTALL_URL="https://get.rke2.io/install-rke2.sh"
