$TTL 604800
$ORIGIN homelab.kubernerdes.com.
@	IN SOA      nuc-00.homelab.kubernerdes.com.  root.homelab.kubernerdes.com. (
            2026040101 ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL

             IN NS       nuc-00-01.homelab.kubernerdes.com.
             IN NS       nuc-00-02.homelab.kubernerdes.com.

; Infra devices
gateway		IN	A	10.0.0.1
cisco-sg300-28	IN 	A	10.0.0.2
airport-extreme IN 	A	10.0.0.3
;
nuc-00-01	IN	A	10.0.0.8
nuc-00-02	IN	A	10.0.0.9
nuc-00 		IN	A	10.0.0.10
librenms	IN	A	10.0.0.12
glkvm		IN	A	10.0.0.20

; Load Balancer for Harvester Cluster(s) - one LB per Harvester Cluster
; These are the Host Addresses - VIPs defined below
nuc-00-03	IN	A	10.0.0.93

; Hardware Devices in the 1xx range
; NUC cluster (Harvester Edge)
harvester	IN	A	10.0.0.100
nuc-01		IN	A	10.0.0.101
nuc-02		IN	A	10.0.0.102
nuc-03		IN	A	10.0.0.103

nuc-01-kvm	IN	A	10.0.0.111
nuc-02-kvm	IN	A	10.0.0.112
nuc-03-kvm	IN	A	10.0.0.113

; HAProxy VIP
nuc-00-03-vip	IN	A	10.0.0.193

; Rancher Cluster
rancher		IN	A	10.0.0.210
rancher-01	IN	A	10.0.0.211
rancher-02	IN	A	10.0.0.212
rancher-03	IN	A	10.0.0.213

; Observability Cluster
observability		IN	A	10.0.0.220
observability-01 	IN 	A 	10.0.0.221
observability-02 	IN	A 	10.0.0.222
observability-03 	IN	A 	10.0.0.223

; Applications Cluster
apps 		IN	A	10.0.0.230
apps-01 	IN 	A 	10.0.0.231
apps-02 	IN	A 	10.0.0.232
apps-03 	IN	A 	10.0.0.233

; Wildcard for apps cluster ingress
*.applications.homelab.kubernerdes.com. 	IN 	A 	10.0.0.230

; Other hosts
spark-e		IN	A	10.0.0.251

; DHCP pool 10.0.3.0/24
dhcp-1	 IN	 A	 10.0.3.1
dhcp-2	 IN	 A	 10.0.3.2
dhcp-3	 IN	 A	 10.0.3.3
dhcp-4	 IN	 A	 10.0.3.4
dhcp-5	 IN	 A	 10.0.3.5
dhcp-6	 IN	 A	 10.0.3.6
dhcp-7	 IN	 A	 10.0.3.7
dhcp-8	 IN	 A	 10.0.3.8
dhcp-9	 IN	 A	 10.0.3.9
dhcp-10	 IN	 A	 10.0.3.10
