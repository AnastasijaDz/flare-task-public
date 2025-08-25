output "secure_deployment" {
  description = "Whether secure deployment is enabled"
  value       = var.secure_deployment
}

output "vm_name" {
  description = "Name of the created VM"
  value       = google_compute_instance.go_flare_vm.name
}

output "vm_internal_ip" {
  description = "Internal IP address of the VM"
  value       = google_compute_instance.go_flare_vm.network_interface[0].network_ip
}

output "vm_external_ip" {
  description = "External IP address of the VM only for standard deployment"
  value       = var.secure_deployment ? null : google_compute_instance.go_flare_vm.network_interface[0].access_config[0].nat_ip
}

output "bastion_external_ip" {
  description = "External IP address of the bastion host for secure deployment"
  value       = var.secure_deployment ? google_compute_instance.bastion[0].network_interface[0].access_config[0].nat_ip : null
}

output "load_balancer_ip" {
  description = "Load balancer IP for API access for secure deployment"
  value       = var.secure_deployment ? google_compute_global_address.lb_ip[0].address : null
}

output "flare_api_endpoint" {
  description = "Flare API endpoint URL"
  value = var.secure_deployment ? "http://${google_compute_global_address.lb_ip[0].address}" : "http://${google_compute_instance.go_flare_vm.network_interface[0].access_config[0].nat_ip}:9650"
}

output "ssh_connection_info" {
  description = "SSH connection information"
  value = {
    secure_deployment = var.secure_deployment
    secure_ssh = var.secure_deployment ? "ssh ${var.ssh_user}@${google_compute_instance.bastion[0].network_interface[0].access_config[0].nat_ip}" : null
    secure_vm_via_bastion = var.secure_deployment ? "ssh -J ${var.ssh_user}@${google_compute_instance.bastion[0].network_interface[0].access_config[0].nat_ip} ${var.ssh_user}@${google_compute_instance.go_flare_vm.network_interface[0].network_ip}" : null
  }
}

output "network_info" {
  description = "Network configuration details"
  value = {
    network_name = google_compute_network.go_flare_network.name
    subnet_name  = google_compute_subnetwork.go_flare_subnet.name
    subnet_cidr  = google_compute_subnetwork.go_flare_subnet.ip_cidr_range
    cloud_nat_enabled = var.secure_deployment
    load_balancer_enabled = var.secure_deployment
  }
}