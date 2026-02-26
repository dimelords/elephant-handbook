# Development Environment Configuration

environment = "dev"
location    = "westeurope"

# Network
vnet_cidr           = "10.0.0.0/16"
aks_subnet_cidr     = "10.0.0.0/20"
postgres_subnet_cidr = "10.0.16.0/24"
service_cidr        = "10.1.0.0/16"
dns_service_ip      = "10.1.0.10"

# AKS
kubernetes_version = "1.28"
vm_size           = "Standard_D4s_v3"  # 4 vCPU, 16GB RAM
node_count        = 2
min_node_count    = 1
max_node_count    = 3
os_disk_size_gb   = 100

# Database
db_sku_name               = "B_Standard_B2s"  # 2 vCPU, 4GB RAM (Burstable)
db_storage_mb             = 32768  # 32GB
db_storage_tier           = "P10"
db_zone                   = "1"
db_high_availability      = false
db_backup_retention_days  = 7
db_geo_redundant_backup   = false

# Storage
storage_replication_type = "LRS"  # Locally redundant

# Monitoring
log_retention_days = 30

# Security
enable_purge_protection = false

# Estimated cost: ~$250-350/month
# - AKS: ~$150/month (2 nodes)
# - PostgreSQL: ~$60/month (Burstable tier)
# - Storage: ~$20/month
# - Log Analytics: ~$20/month
