# Production Environment Configuration

environment = "production"
region      = "europe-west1"

# Network
subnet_cidr    = "10.0.0.0/20"
pods_cidr      = "10.4.0.0/14"
services_cidr  = "10.8.0.0/20"
master_cidr    = "172.16.0.0/28"

# Restrict access to known IPs
authorized_networks = [
  {
    cidr = "203.0.113.0/24"
    name = "office"
  }
]

# GKE
gke_release_channel  = "STABLE"
machine_type         = "e2-standard-8"  # 8 vCPU, 32GB RAM
disk_size_gb         = 200
node_count_per_zone  = 2
min_node_count       = 2
max_node_count       = 5
use_spot_instances   = false  # Use regular instances for production

# Database
db_tier              = "db-custom-4-16384"  # 4 vCPU, 16GB RAM
db_availability_type = "REGIONAL"  # High availability
db_disk_size         = 500

# Security
enable_deletion_protection = true
enable_cmek               = true  # Customer-managed encryption

# Estimated cost: ~$800-1200/month
# - GKE: ~$600/month (6 nodes total)
# - Cloud SQL: ~$350/month (regional HA)
# - Storage: ~$50/month
# - KMS: ~$5/month
