# Files/overrides/carbide/

Environment-specific file overrides for the **Carbide** environment.

Files in this directory are applied **on top of** the common `Files/` baseline
when `ENVIRONMENT=carbide`. They follow the same directory structure as `Files/`
so the override path is clear.

## Current overrides

| File | Purpose |
|------|---------|
| *(none yet)* | |

## When to add an override

Add a file here when the Carbide environment requires a different version of a
common config file. For example:

- **Harvester registry mirror** — `nuc-00-01/etc/registries.yaml` pointing to
  `registry.rancher.com` instead of pulling direct from Docker Hub
- **RKE2 registry config** — `/etc/rancher/rke2/registries.yaml` on cluster
  nodes configured to mirror from `registry.rancher.com`

## How overrides are applied

The `nuc-00-*/post_install.sh` scripts check for an override at:
```
${REPO_BASE}/Files/overrides/${ENVIRONMENT}/<path>
```
before falling back to the common:
```
${REPO_BASE}/Files/<path>
```
