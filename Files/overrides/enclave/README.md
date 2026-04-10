# Files/overrides/enclave/

Environment-specific file overrides for the **Enclave** (air-gap) environment.

Files in this directory are applied **on top of** the common `Files/` baseline
when `ENVIRONMENT=enclave`. They follow the same directory structure as `Files/`.

## Current overrides

| File | Purpose |
|------|---------|
| *(none yet — Harbor setup pending)* | |

## When to add an override

Add a file here when the Enclave environment requires a different version of a
common config file. Key examples:

- **Harvester registry mirror** — `nuc-00-01/etc/registries.yaml` pointing to
  local Harbor (`${HARBOR_HOSTNAME}`) instead of public registries
- **RKE2 registry config** — `/etc/rancher/rke2/registries.yaml` with a
  wildcard mirror to `${HARBOR_HOSTNAME}` for all image pulls
- **named.conf** — reverse DNS zones for `10.10.12.0/22` differ from
  the community `10.0.0.0/22` zone names:
  - `12.10.10.in-addr.arpa` (10.10.12.x)
  - `13.10.10.in-addr.arpa` (10.10.13.x)
  - `14.10.10.in-addr.arpa` (10.10.14.x)
  - `15.10.10.in-addr.arpa` (10.10.15.x)

## How overrides are applied

See `Files/overrides/carbide/README.md` for the pattern.
