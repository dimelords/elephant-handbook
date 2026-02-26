terraform {
  required_version = ">= 1.5"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.environment}-elephant-rg"
  location = var.location

  tags = merge(
    {
      Environment = var.environment
      Application = "elephant"
    },
    var.tags
  )
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.environment}-elephant-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_cidr]

  tags = azurerm_resource_group.main.tags
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "${var.environment}-elephant-aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# Subnet for PostgreSQL
resource "azurerm_subnet" "postgres" {
  name                 = "${var.environment}-elephant-postgres-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.postgres_subnet_cidr]

  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.environment}-elephant-postgres.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.environment}-elephant-postgres-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id

  tags = azurerm_resource_group.main.tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.environment}-elephant-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.environment}-elephant"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = var.min_node_count
    max_count           = var.max_node_count
    os_disk_size_gb     = var.os_disk_size_gb
    
    upgrade_settings {
      max_surge = "10%"
    }

    tags = azurerm_resource_group.main.tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  azure_policy_enabled = true

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [3, 4]
    }
  }

  tags = azurerm_resource_group.main.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.environment}-elephant-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = azurerm_resource_group.main.tags
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.environment}-elephant-postgres"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16"
  delegated_subnet_id    = azurerm_subnet.postgres.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  administrator_login    = "elephant_admin"
  administrator_password = var.db_password
  zone                   = var.db_zone

  storage_mb   = var.db_storage_mb
  storage_tier = var.db_storage_tier

  sku_name = var.db_sku_name

  backup_retention_days        = var.db_backup_retention_days
  geo_redundant_backup_enabled = var.db_geo_redundant_backup

  high_availability {
    mode                      = var.db_high_availability ? "ZoneRedundant" : "Disabled"
    standby_availability_zone = var.db_high_availability ? var.db_standby_zone : null
  }

  maintenance_window {
    day_of_week  = 0 # Sunday
    start_hour   = 3
    start_minute = 0
  }

  tags = azurerm_resource_group.main.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "elephant" {
  name      = "elephant"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# PostgreSQL Configuration
resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "200"
}

resource "azurerm_postgresql_flexible_server_configuration" "shared_buffers" {
  name      = "shared_buffers"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "2097152" # 2GB in 8KB pages
}

# Storage Account for Blob Storage
resource "azurerm_storage_account" "main" {
  name                     = "${var.environment}elephantstore"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
    bypass                     = ["AzureServices"]
  }

  tags = azurerm_resource_group.main.tags
}

# Blob Container
resource "azurerm_storage_container" "archive" {
  name                  = "elephant-archive"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Key Vault for Secrets
resource "azurerm_key_vault" "main" {
  name                       = "${var.environment}-elephant-kv"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 90
  purge_protection_enabled   = var.enable_purge_protection

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
  }

  tags = azurerm_resource_group.main.tags
}

data "azurerm_client_config" "current" {}

# Key Vault Access Policy for AKS
resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Store database password in Key Vault
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.aks]
}

# Managed Identity for Elephant
resource "azurerm_user_assigned_identity" "elephant" {
  name                = "${var.environment}-elephant-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = azurerm_resource_group.main.tags
}

# Role Assignment for Storage
resource "azurerm_role_assignment" "elephant_storage" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.elephant.principal_id
}

# Role Assignment for Key Vault
resource "azurerm_key_vault_access_policy" "elephant" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.elephant.principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Outputs
output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Resource group name"
}

output "aks_cluster_name" {
  value       = azurerm_kubernetes_cluster.main.name
  description = "AKS cluster name"
}

output "aks_cluster_id" {
  value       = azurerm_kubernetes_cluster.main.id
  description = "AKS cluster ID"
}

output "database_fqdn" {
  value       = azurerm_postgresql_flexible_server.main.fqdn
  description = "PostgreSQL FQDN"
}

output "storage_account_name" {
  value       = azurerm_storage_account.main.name
  description = "Storage account name"
}

output "storage_container_name" {
  value       = azurerm_storage_container.archive.name
  description = "Storage container name"
}

output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "Key Vault name"
}

output "managed_identity_client_id" {
  value       = azurerm_user_assigned_identity.elephant.client_id
  description = "Managed identity client ID"
}

output "configure_kubectl" {
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
  description = "Command to configure kubectl"
}
