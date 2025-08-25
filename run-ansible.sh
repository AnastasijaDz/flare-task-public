#!/bin/bash
set -e

ANSIBLE_DIR="ansible"
PLAYBOOK="deploy-goflare.yml"

# Function to create temporary SSH access if needed
create_temp_ssh_access() {
    echo -e "Setting up temporary SSH access for secure deployment..."
    
    MY_IP=$(curl -s ifconfig.me)
        
    # Check if rule already exists
    if gcloud compute firewall-rules describe temp-ssh-access --quiet 2>/dev/null; then
        gcloud compute firewall-rules update temp-ssh-access \
            --source-ranges=${MY_IP}/32
    else
        gcloud compute firewall-rules create temp-ssh-access \
            --network=flare-network \
            --allow=tcp:22 \
            --source-ranges=${MY_IP}/32 \
            --target-tags=bastion-host \
            --description="Temporary SSH access for Ansible deployment"
    fi
    
    # Set trap to cleanup on exit
    trap cleanup_temp_ssh_access EXIT
}

# Function to cleanup temporary SSH access
cleanup_temp_ssh_access() {
    echo -e "Cleaning up temporary SSH access."
    if gcloud compute firewall-rules describe temp-ssh-access --quiet 2>/dev/null; then
        gcloud compute firewall-rules delete temp-ssh-access --quiet
    fi
}

# Check if Terraform has created the inventory
if [ ! -f "${ANSIBLE_DIR}/inventory/hosts" ]; then
    echo -e "Error: Ansible inventory file not found!"
    echo "Please run 'terraform apply' first to generate the inventory."
    exit 1
fi

echo -e "Starting go-flare observer node deployment."

cd "${ANSIBLE_DIR}"
SECURE_DEPLOYMENT=$(grep -q "secure_deployment=true" inventory/hosts && echo "true" || echo "false")

if [ "$SECURE_DEPLOYMENT" = "true" ]; then    
    # Create temporary SSH access
    create_temp_ssh_access
    # Wait a moment for firewall rule to propagate
    sleep 10
    
    # Clear any existing SSH host keys for the bastion IP
    BASTION_IP=$(grep "ansible_host=" inventory/hosts | grep bastion | cut -d'=' -f2 | cut -d' ' -f1)
    ssh-keygen -R "${BASTION_IP}" 2>/dev/null || true
    
    if ! ansible bastion -m ping; then
        echo -e "Error: Cannot connect to bastion host!"
        exit 1
    fi

    # Clear any existing SSH host keys for the VM internal IP
    VM_INTERNAL_IP=$(grep "vm_internal_ip=" inventory/hosts | cut -d'=' -f2 | cut -d' ' -f1)
    ssh-keygen -R "${VM_INTERNAL_IP}" 2>/dev/null || true
    
    if ! ansible flare_nodes -m ping; then
        exit 1
    fi    
else    
    # Clear any existing SSH host keys for the VM external IP
    VM_EXTERNAL_IP=$(grep "ansible_host=" inventory/hosts | grep -v bastion | cut -d'=' -f2 | cut -d' ' -f1)
    ssh-keygen -R "${VM_EXTERNAL_IP}" 2>/dev/null || true
    
    # Test direct connectivity
    if ! ansible flare_nodes -m ping; then
        echo -e "Error: Cannot connect directly to VM!"
        exit 1
    fi    
fi

echo -e "Running Ansible playbook."
ansible-playbook "${PLAYBOOK}" -v

echo -e "Deployment completed"