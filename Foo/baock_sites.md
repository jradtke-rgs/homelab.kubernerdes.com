# Block Sites with NeuVector

## Status
Work in progress


NeuVector provides domain-based network policy enforcement through its **Network Rules** system. Here's how to block domains:

## How NeuVector Handles Domain Blocking

NeuVector operates at Layer 7 (application layer) and can inspect and enforce policies on DNS-resolved hostnames, not just IP addresses. This is particularly powerful because it handles dynamic IPs automatically.

## Methods to Block Domains

### 1. Network Policy Rules (Primary Method)

Navigate to **Policy → Network Rules** in the NeuVector UI and create a rule with:

- **From**: your workload group (or `nodes` / `containers`)
- **To**: `external` (for egress to internet)
- **Action**: `Deny`
- **Ports**: `any` or specific ports (443, 80, etc.)

The key is using the **Destination** field where you can specify a domain/FQDN. NeuVector will resolve and track IPs associated with that domain dynamically.

### 2. Via CRD (Kubernetes-Native)

```yaml
apiVersion: neuvector.com/v1
kind: NvNetworkRule
metadata:
  name: block-bad-domain
  namespace: neuvector
spec:
  from:
    - selector:
        matchLabels:
          app: my-app
  to:
    - fqdn: "malicious-domain.com"
  action: deny
  ports: any
```

### 3. DNS/FQDN Groups

Go to **Policy → Groups** and create a custom group based on FQDN:

1. Create a new group → set type to **FQDN**
2. Enter the domain (e.g., `*.badsite.com` — wildcards supported)
3. Reference this group in your Network Rules as the destination with action `Deny`

This is the cleanest approach for managing multiple domains.

### 4. Process Profile + Network Policy Combo

For tighter control, combine:
- A **Process Profile** rule blocking specific processes from making network calls
- A **Network Rule** blocking the FQDN

## Key Behavioral Notes

- **Discover → Monitor → Protect**: Domain blocking rules are only *enforced* when the workload/group is in **Protect** mode. In Discover or Monitor, violations are logged but not blocked.
- **DNS interception**: NeuVector intercepts DNS responses to map FQDNs to IPs dynamically — so domain rules stay accurate even as CDN/cloud IPs rotate.
- **Wildcard support**: `*.example.com` notation works for subdomain blocking.
- **Egress direction**: Domain blocking is most commonly applied to **egress** traffic (pod → external). Ingress domain filtering is less common and typically handled at the ingress controller level.

## Verify the Block is Working

Check **Network Activity** or **Security Events** under the NeuVector dashboard — blocked egress attempts will show up as **Network Violation** events with the destination FQDN and the enforcing rule.

For air-gapped/DoD environments, this is especially useful for allowlisting known-good registries (like Harbor) and blocking everything else via a default-deny egress posture with explicit FQDN allows.
