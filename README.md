# Go-Flare Observer Node Deployment

Automated deployment of go-flare observer node on GCP using Terraform and Ansible.

## Architecture

Two deployment modes controlled by `secure_deployment` variable:

### Standard Mode (`secure_deployment = false`)
- VM with public IP
- Direct SSH and API access  

### Secure Mode (`secure_deployment = true`)
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

## Configuration
Create a terraform.tfvars file in the terraform directory:
```hcl
# GCP settings
project_id = "gcp-project-id"
region     = "europe-west3"
zone       = "europe-west3-a"

# Network configuration
network_name = "flare-network"
subnet_name  = "flare-subnet"
subnet_cidr  = "10.0.1.0/24"

# VM configuration
vm_name      = "flare-vm"
machine_type = "e2-medium"
disk_size_gb = 50

# SSH configuration
ssh_user            = "ubuntu"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Deployment mode
secure_deployment = true  # Set to false for standard deployment
```

## Deployment

```bash
# 1. Deploy infrastructure
cd terraform
terraform init
terraform apply

# 2. Deploy application
./run-ansible.sh
```

The `run-ansible.sh` script handles:
- Automatic deployment mode detection
- Temporary firewall access for secure deployments
- SSH connectivity testing
- Ansible playbook execution with proper inventory

## Access Points

### Standard Deployment
- **API**: `http://<vm-ip>:9650/ext/health`
- **SSH**: `ssh ubuntu@<vm-ip>`

### Secure Deployment
- **API**: `http://<load-balancer-ip>/ext/health`
- **SSH**: `ssh -J ubuntu@<bastion-ip> ubuntu@<vm-internal-ip>`
