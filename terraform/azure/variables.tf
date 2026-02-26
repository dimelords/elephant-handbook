# General Configuration
variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

# Network Configuration
variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR block for AKS subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "postgres_subnet_cidr" {
  description = "CIDR block for PostgreSQL subnet"
  type        = string
  default     = "10.0.16.0/24"
}

variable "service_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.1.0.10"
}

# AKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D4s_v3" # 4 vCPU, 16GB RAM
}

variable "node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum number of nodes"
  type        = number
  default     = 5
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 100
}

# Database Configuration
variable "db_sku_name" {
  description = "PostgreSQL SKU name"
  type        = string
  default     = "GP_Standard_D2s_v3" # 2 vCPU, 8GB RAM
}

variable "db_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 131072 # 128GB
}

variable "db_storage_tier" {
  description = "PostgreSQL storage tier"
  type        = string
  default     = "P30"
}

variable "db_zone" {
  description = "Availability zone for PostgreSQL"
  type        = string
  default     = "1"
}

variable "db_standby_zone" {
  description = "Standby availability zone for PostgreSQL HA"
  type        = string
  default     = "2"
}

variable "db_high_availability" {
  description = "Enable high availability for PostgreSQL"
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "db_geo_redundant_backup" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}

variable "db_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

# Storage Configuration
variable "storage_replication_type" {
  description = "Storage replication type (LRS, GRS, RAGRS, ZRS)"
  type        = string
  default     = "LRS"
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

# Security Configuration
variable "enable_purge_protection" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
