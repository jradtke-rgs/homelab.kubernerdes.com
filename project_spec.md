# Kubernerdes Homelab Overview
homelab.kubernerdes.com - This repo will be the landing page for deploying, SUSE Rancher, Harvester, and related bits, using different methods and implementation approaches.

My goal(s):
- have a single code base that can build out an entire environment 
- have the ability to select which envirnment based on config/env files 
- deploy: Harvester (Virtualization), RKE2, Rancher Manager, StackState (Observability), "apps" K8s cluster with NeuVector (Security)
- associated documentation for this technical project which provides a "human readable" narrative explainung what this repo is for and what the reader can expect to learn, etc...

## Milestones
Build an MVP starting with community bits, then carbide, followed by enclave

## Approaches
Carbide =  RGS Software pulled over the Internet  
Enclave = RGS Software synced using Hauler, then hosted with harbor for airgapped deployments  
Community = SUSE bits pulled from public sources  

Top-level Domain: kubernerdes.com  
Tertiary-Level Domain: the "environment" will be identify the tertiary-level domain - i.e carbide.kubernerdes.com

| Environment | CIDR |
|:-:|:---|
| Community | 10.0.0.0/22
| Carbide | 10.10.12.0/22
| Enclave  | 10.10.12.0/22

*.apps.$environment.$domain = ${IP_PREFIX}.230

## IP assignments
| IP | Host | Purpose |
|:-:|:---|:------|
| .8 | |
| .9 | |
| .10 | |
| .93 | |
| .100 | |
| .210 | |
| .220 | |
| .230 | |
| .8 | |
| .8 | |

