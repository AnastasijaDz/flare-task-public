# Go-Flare Observer Node Deployment

Automated deployment of go-flare observer node on GCP using Terraform and Ansible.

## Architecture

Two deployment modes controlled by `secure_deployment` variable:

**Standard Mode (`secure_deployment = false`)**
- VM with public IP
- Direct SSH and API access
- Simple development setup

**Secure Mode (`secure_deployment = true`)**
- Private VM with bastion host access
- Load balancer for public API exposure
- NAT gateway for outbound internet access
- IAP-based SSH authentication

## Infrastructure Components

### Terraform Resources
- Custom VPC network with dedicated subnet
- VM instance with additional SSD data disk
- Conditional resources based on deployment mode:
  - Bastion host (secure only)
  - Load balancer chain (secure only) 
  - NAT router/gateway (secure only)
- Firewall rules for ports 9650 (API), 9651 (P2P), and SSH

### Key Configuration
- Ubuntu 24.04 LTS
- Go-flare version v1.11.0
- Coston2 testnet with state-sync enabled
- Docker Compose deployment
- Persistent database storage on `/mnt/db`

## Deployment

```bash
# 1. Deploy infrastructure
cd terraform
terraform init
terraform apply -var="secure_deployment=true"

# 2. Deploy application
./run-ansible.sh
```

The `run-ansible.sh` script handles:
- Automatic deployment mode detection
- Temporary firewall access for secure deployments
- SSH connectivity testing
- Ansible playbook execution with proper inventory

## Access Points

**Standard Deployment:**
- API: `http://<vm-ip>:9650/ext/health`
- SSH: `ssh ubuntu@<vm-ip>`

**Secure Deployment:**
- API: `http://<load-balancer-ip>/ext/health`
- SSH: `ssh -J ubuntu@<bastion-ip> ubuntu@<vm-internal-ip>`
