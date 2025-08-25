terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# custom VPC network
resource "google_compute_network" "go_flare_network" {
  name                    = var.network_name
  auto_create_subnetworks = false
  description             = "Custom VPC network for go-flare application"
}

# subnet in the custom VPC
resource "google_compute_subnetwork" "go_flare_subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.go_flare_network.id
  description   = "Subnet for go-flare VMs"
}

# cloud NAT router for secure deployment
resource "google_compute_router" "nat_router" {
  count   = var.secure_deployment ? 1 : 0
  name    = "${var.network_name}-nat-router"
  region  = var.region
  network = google_compute_network.go_flare_network.id

  # required BGP with ASN in the privvate range
  bgp {
    asn = 64514
  }
}

# cloud NAT gateway for secure scenario
resource "google_compute_router_nat" "nat_gateway" {
  count  = var.secure_deployment ? 1 : 0
  name   = "${var.network_name}-nat-gateway"
  router = google_compute_router.nat_router[0].name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# bastion host for ansible access, for secure scenario
resource "google_compute_instance" "bastion" {
  count        = var.secure_deployment ? 1 : 0
  name         = "${var.vm_name}-bastion"
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["bastion-host"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.go_flare_network.id
    subnetwork = google_compute_subnetwork.go_flare_subnet.id
    
    # public IP for ansible access
    access_config {
      # temporary public IP
    }
  }

  metadata = {
    ssh-keys       = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
    enable-oslogin = "FALSE"
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

# firewall rule for Flare API (port 9650)
resource "google_compute_firewall" "allow_flare_api" {
  name    = "allow-flare-api"
  network = google_compute_network.go_flare_network.name

  allow {
    protocol = "tcp"
    ports    = ["9650"]  # API port
  }

  # standard deployment: open to internet
  # secure deployment: only internal network
  source_ranges = var.secure_deployment ? [var.subnet_cidr] : ["0.0.0.0/0"]
  target_tags   = ["go-flare-vm"]
  description   = "Allow Flare API access on port 9650"
}

# firewall rule for Flare P2P/Staking (port 9651)
resource "google_compute_firewall" "allow_flare_p2p_staking" {
  name    = "allow-flare-p2p-staking"
  network = google_compute_network.go_flare_network.name

  allow {
    protocol = "tcp"
    ports    = ["9651"]  # P2P/Staking
  }

  allow {
    protocol = "udp" 
    ports    = ["9651"]  # P2P/Staking
  }

  source_ranges = ["0.0.0.0/0"]  # must remain open for P2P discovery
  target_tags   = ["go-flare-vm"]
  description   = "Allow Flare P2P/Staking communication on port 9651 - must be publicly reachable"
}

# direct SSH access for standard deployment
resource "google_compute_firewall" "allow_ssh_direct" {
  count   = var.secure_deployment ? 0 : 1
  name    = "allow-ssh-direct"
  network = google_compute_network.go_flare_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["go-flare-vm"]
  description   = "Allow direct SSH access"
}

# SSH from bastion to internal VMs for secure deployment
resource "google_compute_firewall" "allow_ssh_internal" {
  count   = var.secure_deployment ? 1 : 0
  name    = "allow-ssh-internal"
  network = google_compute_network.go_flare_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion-host"]
  target_tags = ["go-flare-vm"]
  description = "Allow SSH from bastion to internal VMs"
}

resource "google_compute_firewall" "allow_ssh_bastion" {
  count   = var.secure_deployment ? 1 : 0
  name    = "allow-ssh-bastion"
  network = google_compute_network.go_flare_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion-host"]
  description   = "Allow SSH to bastion via IAP only"
}

resource "google_compute_firewall" "allow_health_check" {
  count   = var.secure_deployment ? 1 : 0
  name    = "allow-health-check"
  network = google_compute_network.go_flare_network.name

  allow {
    protocol = "tcp"
    ports    = ["9650"]
  }

  # Google Cloud health check IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["go-flare-vm"]
  description   = "Allow Google Cloud health checks"
}

# egress firewall rule
resource "google_compute_firewall" "allow_flare_egress" {
  name    = "allow-flare-egress"
  network = google_compute_network.go_flare_network.name

  allow {
    protocol = "tcp"
    ports    = ["443", "80", "9651", "9650"]
  }

  allow {
    protocol = "udp"
    ports    = ["53", "9651"]  # DNS and P2P
  }

  direction = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
  target_tags   = ["go-flare-vm", "bastion-host"]
  description   = "Allow outbound traffic for Flare node operation"
}

# additional data disk for go-flare database
resource "google_compute_disk" "go_flare_data_disk" {
  name = "${var.vm_name}-data-disk"
  type = "pd-ssd"
  zone = var.zone
  size = var.disk_size_gb
  labels = {
    environment = "development"
    purpose     = "go-flare-database"
  }
}

# static external IP for standard deployment
resource "google_compute_address" "go_flare_static_ip" {
  count  = var.secure_deployment ? 0 : 1
  name   = "${var.vm_name}-static-ip"
  region = var.region
}

# node VM
resource "google_compute_instance" "go_flare_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["go-flare-vm"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 100
      type  = "pd-ssd"
    }
  }

  # attaching the additional data disk
  attached_disk {
    source      = google_compute_disk.go_flare_data_disk.id
    device_name = "go-flare-data"
  }

  network_interface {
    network    = google_compute_network.go_flare_network.id
    subnetwork = google_compute_subnetwork.go_flare_subnet.id
    
    # public IP for standard deployment
    # private IP only for secure deployment
    dynamic "access_config" {
      for_each = var.secure_deployment ? [] : [1]
      content {
        nat_ip = var.secure_deployment ? null : google_compute_address.go_flare_static_ip[0].address
      }
    }
  }

  metadata = {
    ssh-keys       = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
    enable-oslogin = "FALSE"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y curl wget
    
    # Format and mount the additional disk
    if ! blkid /dev/disk/by-id/google-go-flare-data; then
      mkfs.ext4 -F /dev/disk/by-id/google-go-flare-data
    fi
    
    mkdir -p /data/go-flare
    mount /dev/disk/by-id/google-go-flare-data /data/go-flare
    
    # Add to fstab for persistent mounting
    echo '/dev/disk/by-id/google-go-flare-data /data/go-flare ext4 defaults 0 2' >> /etc/fstab
    
    # Set permissions
    chown -R $USER:$USER /data/go-flare
  EOF

  service_account {
    scopes = ["cloud-platform"]
  }

  # depends on NAT gateway for secure deployment
  depends_on = [
    google_compute_router_nat.nat_gateway
  ]
}

# instance Group
resource "google_compute_instance_group" "go_flare_group" {
  name        = "${var.vm_name}-group"
  description = "Instance group for go-flare VM"
  zone        = var.zone

  instances = [
    google_compute_instance.go_flare_vm.id
  ]

  named_port {
    name = "rpc"
    port = "9650"
  }
}

# load balancer for API access for secure deployment
resource "google_compute_global_address" "lb_ip" {
  count = var.secure_deployment ? 1 : 0
  name  = "${var.vm_name}-lb-ip"
}

resource "google_compute_health_check" "flare_health_check" {
  count = var.secure_deployment ? 1 : 0
  name  = "${var.vm_name}-health-check"

  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = "9650"
    request_path = "/ext/health"
  }
}

resource "google_compute_backend_service" "flare_backend" {
  count         = var.secure_deployment ? 1 : 0
  name          = "${var.vm_name}-backend"
  health_checks = [google_compute_health_check.flare_health_check[0].id]
  port_name     = "rpc"
  protocol      = "HTTP"
  timeout_sec   = 30

  backend {
    group = google_compute_instance_group.go_flare_group.id
  }
}

resource "google_compute_url_map" "flare_url_map" {
  count           = var.secure_deployment ? 1 : 0
  name            = "${var.vm_name}-url-map"
  default_service = google_compute_backend_service.flare_backend[0].id
}

resource "google_compute_target_http_proxy" "flare_proxy" {
  count   = var.secure_deployment ? 1 : 0
  name    = "${var.vm_name}-proxy"
  url_map = google_compute_url_map.flare_url_map[0].id
}

resource "google_compute_global_forwarding_rule" "flare_forwarding_rule" {
  count      = var.secure_deployment ? 1 : 0
  name       = "${var.vm_name}-forwarding-rule"
  target     = google_compute_target_http_proxy.flare_proxy[0].id
  port_range = "80"
  ip_address = google_compute_global_address.lb_ip[0].address
}

# generating ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    secure_deployment   = var.secure_deployment
    vm_name            = google_compute_instance.go_flare_vm.name
    vm_internal_ip     = google_compute_instance.go_flare_vm.network_interface[0].network_ip
    vm_external_ip     = var.secure_deployment ? null : google_compute_instance.go_flare_vm.network_interface[0].access_config[0].nat_ip
    bastion_external_ip = var.secure_deployment ? google_compute_instance.bastion[0].network_interface[0].access_config[0].nat_ip : null
    bastion_internal_ip = var.secure_deployment ? google_compute_instance.bastion[0].network_interface[0].network_ip : null
    ssh_user           = var.ssh_user
    project_id         = var.project_id
    zone              = var.zone
  })
  filename = "${path.module}/../ansible/inventory/hosts"
}