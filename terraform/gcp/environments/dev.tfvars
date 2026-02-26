# Development Environment Configuration

environment = "dev"
region      = "europe-west1"

# Network
subnet_cidr    = "10.0.0.0/20"
pods_cidr      = "10.4.0.0/14"
services_cidr  = "10.8.0.0/20"
master_cidr    = "172.16.0.0/28"

# GKE
gke_release_channel  = "REGULAR"
machine_type         = "e2-standard-4"  # 4 vCPU, 16GB RAM
disk_size_gb         = 100
node_count_per_zone  = 1
min_node_count       = 1
max_node_count       = 2
use_spot_instances   = true  # Cost savings for dev

# Database
db_tier              = "db-custom-2-8192"  # 2 vCPU, 8GB RAM
db_availability_type = "ZONAL"
db_disk_size         = 50

# Security
enable_deletion_protection = false
enable_cmek               = false

# Estimated cost: ~$200-300/month
# - GKE: ~$150/month (1 node per zone with spot)
# - Cloud SQL: ~$80/month
# - Storage: ~$10/month
