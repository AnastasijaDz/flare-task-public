%{ if secure_deployment }
# secure deployment with bastion host
[bastion]
bastion-host ansible_host=${bastion_external_ip} ansible_user=${ssh_user}

[flare_nodes]
${vm_name} ansible_host=${vm_internal_ip} ansible_user=${ssh_user} vm_internal_ip=${vm_internal_ip}

[flare_nodes:vars]
ansible_ssh_common_args=-o ProxyCommand="ssh -W %h:%p -q ${ssh_user}@${bastion_external_ip}"
secure_deployment=true

%{ else }
# standard deployment with direct access
[flare_nodes]
${vm_name} ansible_host=${vm_external_ip} ansible_user=${ssh_user} vm_internal_ip=${vm_internal_ip}

[flare_nodes:vars]
secure_deployment=false
%{ endif }