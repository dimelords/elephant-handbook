# Production Environment Configuration

environment = "production"
location    = "westeurope"

# Network
vnet_cidr           = "10.0.0.0/16"
aks_subnet_cidr     = "10.0.0.0/20"
postgres_subnet_cidr = "10.0.16.0/24"
service_cidr        = "10.1.0.0/16"
dns_service_ip      = "10.1.0.10"

# AKS
kubernetes_version = "1.28"
vm_size           = "Standard_D8s_v3"  # 8 vCPU, 32GB RAM
node_count        = 3
min_node_count    = 3
max_node_count    = 10
os_disk_size_gb   = 200

# Database
db_sku_name               = "GP_Standard_D4s_v3"  # 4 vCPU, 16GB RAM
db_storage_mb             = 524288  # 512GB
db_storage_tier           = "P40"
db_zone                   = "1"
db_standby_zone           = "2"
db_high_availability      = true  # Zone-redundant HA
db_backup_retention_days  = 35
db_geo_redundant_backup   = true

# Storage
storage_replication_type = "GRS"  # Geo-redundant

# Monitoring
log_retention_days = 90

# Security
enable_purge_protection = true

# Estimated cost: ~$1000-1500/month
# - AKS: ~$700/month (3-10 nodes)
# - PostgreSQL: ~$400/month (HA, larger instance)
# - Storage: ~$100/month (GRS)
# - Log Analytics: ~$50/month
