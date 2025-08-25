variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "europe-west3-a"
}

variable "network_name" {
  description = "Name of the custom VPC network"
  type        = string
  default     = "go-flare-network"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "go-flare-subnet"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "go-flare-vm"
}

variable "disk_size_gb" {
  description = "Size of the additional data disk in GB"
  type        = number
  default     = 100
}

variable "machine_type" {
  description = "Machine type for the VM"
  type        = string
  default     = "e2-standard-4"
}

variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "secure_deployment" {
  description = "Whether to use secure deployment with private IPs and Cloud NAT"
  type        = bool
  default     = false
}

variable "allowed_ssh_sources" {
  description = "List of CIDR blocks allowed to SSH to the VM"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}