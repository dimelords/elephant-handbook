terraform {
  required_version = ">= 1.5"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-elephant-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.environment}-elephant-private"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

# Cloud NAT for private GKE nodes
resource "google_compute_router" "router" {
  name    = "${var.environment}-elephant-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.environment}-elephant-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "${var.environment}-elephant-gke"
  location = var.region

  # Regional cluster for HA
  node_locations = var.node_zones

  # Use VPC-native cluster
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.private.name

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Network configuration
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  # Master authorized networks
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  # Network policy
  network_policy {
    enabled  = true
    provider = "PROVIDER_UNSPECIFIED"
  }

  # Release channel
  release_channel {
    channel = var.gke_release_channel
  }
}

# Node Pool
resource "google_container_node_pool" "primary" {
  name       = "${var.environment}-elephant-nodes"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count_per_zone

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"

    # Use spot instances for cost savings (dev only)
    spot = var.use_spot_instances

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = var.environment
      application = "elephant"
    }

    tags = ["elephant", var.environment]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

# Cloud SQL PostgreSQL
resource "google_sql_database_instance" "postgres" {
  name             = "${var.environment}-elephant-postgres"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier              = var.db_tier
    availability_type = var.db_availability_type
    disk_size         = var.db_disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 30
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
      require_ssl     = true
    }

    database_flags {
      name  = "max_connections"
      value = "200"
    }

    database_flags {
      name  = "shared_buffers"
      value = "262144" # 2GB in 8KB pages
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 3
      update_track = "stable"
    }
  }

  deletion_protection = var.enable_deletion_protection

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Private VPC connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.environment}-elephant-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Database
resource "google_sql_database" "elephant" {
  name     = "elephant"
  instance = google_sql_database_instance.postgres.name
}

# Database user
resource "google_sql_user" "elephant" {
  name     = "elephant_app"
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

# Cloud Storage Bucket
resource "google_storage_bucket" "archive" {
  name          = "${var.project_id}-${var.environment}-elephant-archive"
  location      = var.region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  encryption {
    default_kms_key_name = var.enable_cmek ? google_kms_crypto_key.bucket[0].id : null
  }
}

# KMS for encryption (optional)
resource "google_kms_key_ring" "elephant" {
  count    = var.enable_cmek ? 1 : 0
  name     = "${var.environment}-elephant-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "bucket" {
  count           = var.enable_cmek ? 1 : 0
  name            = "${var.environment}-elephant-bucket-key"
  key_ring        = google_kms_key_ring.elephant[0].id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# Secret Manager for sensitive data
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.environment}-elephant-db-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

# Service Account for Workload Identity
resource "google_service_account" "elephant" {
  account_id   = "${var.environment}-elephant-sa"
  display_name = "Elephant Application Service Account"
}

# IAM bindings for service account
resource "google_storage_bucket_iam_member" "elephant_storage" {
  bucket = google_storage_bucket.archive.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.elephant.email}"
}

resource "google_secret_manager_secret_iam_member" "elephant_secrets" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.elephant.email}"
}

# Workload Identity binding
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.elephant.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[elephant/elephant-repository]"
}

# Outputs
output "gke_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE cluster name"
}

output "gke_cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE cluster endpoint"
  sensitive   = true
}

output "database_connection_name" {
  value       = google_sql_database_instance.postgres.connection_name
  description = "Cloud SQL connection name"
}

output "database_private_ip" {
  value       = google_sql_database_instance.postgres.private_ip_address
  description = "Database private IP"
}

output "storage_bucket_name" {
  value       = google_storage_bucket.archive.name
  description = "GCS bucket name"
}

output "service_account_email" {
  value       = google_service_account.elephant.email
  description = "Service account email for Workload Identity"
}

output "configure_kubectl" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
  description = "Command to configure kubectl"
}
