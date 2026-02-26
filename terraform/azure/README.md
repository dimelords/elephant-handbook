# Elephant on Microsoft Azure

Deploy Elephant to Azure using Terraform with AKS, Azure Database for PostgreSQL, and Blob Storage.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Resource Group                            │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Virtual Network                         │  │
│  │                                                      │  │
│  │  ┌────────────────────────────────────────────┐    │  │
│  │  │         AKS Cluster                        │    │  │
│  │  │                                            │    │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐│    │  │
│  │  │  │  Node    │  │  Node    │  │  Node    ││    │  │
│  │  │  │ (zone-1) │  │ (zone-2) │  │ (zone-3) ││    │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘│    │  │
│  │  │                                            │    │  │
│  │  │  Managed Identity enabled                 │    │  │
│  │  └────────────────────────────────────────────┘    │  │
│  │                                                      │  │
│  │  ┌────────────────────────────────────────────┐    │  │
│  │  │  PostgreSQL Flexible Server 16             │    │  │
│  │  │  (Private endpoint, Automated backups)     │    │  │
│  │  └────────────────────────────────────────────┘    │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │      Storage Account (Blob Storage)                  │  │
│  │      (Versioning, Soft delete, Lifecycle)            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │      Key Vault                                       │  │
│  │      (Secrets, Certificates, Keys)                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │      Log Analytics Workspace                         │  │
│  │      (Monitoring, Diagnostics)                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **AKS Cluster**: Managed Kubernetes with autoscaling
- **PostgreSQL Flexible Server 16**: Managed database with HA option
- **Blob Storage**: Object storage with versioning and lifecycle
- **Managed Identity**: Secure authentication without credentials
- **Private Networking**: VNet integration with private endpoints
- **Key Vault**: Secure secret management
- **Log Analytics**: Centralized logging and monitoring
- **Azure Policy**: Governance and compliance

## Prerequisites

1. **Azure Account** with active subscription
2. **Azure CLI** installed and configured
3. **Terraform** 1.5 or later
4. **kubectl** for Kubernetes management

### Install Tools

```bash
# macOS
brew install azure-cli terraform kubectl

# Verify
az version
terraform version
kubectl version --client
```

### Configure Azure CLI

```bash
# Login
az login

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Register providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.DBforPostgreSQL
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.KeyVault
```

## Quick Start

### 1. Configure Variables

```bash
# Copy example
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

Required variables:
```hcl
environment = "dev"
location    = "westeurope"
db_password = "your-secure-password"
```

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file=environments/dev.tfvars

# Apply (creates all resources)
terraform apply -var-file=environments/dev.tfvars
```

Takes ~15-20 minutes.

### 3. Configure kubectl

```bash
# Get credentials
az aks get-credentials \
  --resource-group dev-elephant-rg \
  --name dev-elephant-aks

# Verify
kubectl get nodes
```

### 4. Deploy Elephant

```bash
# Deploy to AKS
kubectl apply -k ../../kubernetes/base

# Watch deployment
kubectl get pods -n elephant -w
```

## Configuration

### Environment Files

- `environments/dev.tfvars` - Development (~$250-350/month)
- `environments/production.tfvars` - Production (~$1000-1500/month)

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `location` | Azure region | westeurope |
| `vm_size` | AKS node size | Standard_D4s_v3 |
| `node_count` | Initial nodes | 2 |
| `db_sku_name` | PostgreSQL SKU | GP_Standard_D2s_v3 |
| `db_high_availability` | Enable HA | false |

### Network Configuration

```hcl
vnet_cidr            = "10.0.0.0/16"
aks_subnet_cidr      = "10.0.0.0/20"
postgres_subnet_cidr = "10.0.16.0/24"
service_cidr         = "10.1.0.0/16"
dns_service_ip       = "10.1.0.10"
```

## Managed Identity Setup

Elephant uses Azure Managed Identity for secure access.

### Configure Pod Identity

```bash
# Create namespace
kubectl create namespace elephant

# Label namespace for Azure Workload Identity
kubectl label namespace elephant azure.workload.identity/use=true
```

### Use in Deployment

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: elephant-repository
  namespace: elephant
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: elephant-repository
  containers:
  - name: app
    image: ghcr.io/dimelords/elephant-repository:latest
    env:
    - name: AZURE_CLIENT_ID
      value: "YOUR_MANAGED_IDENTITY_CLIENT_ID"
```

## Database Connection

### Connection String

```bash
# Get connection details
terraform output database_fqdn

# Connection string format
postgresql://elephant_admin:PASSWORD@FQDN:5432/elephant?sslmode=require
```

### SSL Certificate

Azure PostgreSQL requires SSL:

```bash
# Download SSL certificate
curl -o DigiCertGlobalRootCA.crt.pem \
  https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem

# Use in connection
psql "host=FQDN port=5432 dbname=elephant user=elephant_admin sslmode=verify-full sslrootcert=DigiCertGlobalRootCA.crt.pem"
```

## Storage Access

### Using Azure CLI

```bash
# List containers
az storage container list --account-name YOUR_STORAGE_ACCOUNT

# Upload file
az storage blob upload \
  --account-name YOUR_STORAGE_ACCOUNT \
  --container-name elephant-archive \
  --name file.txt \
  --file file.txt

# Download file
az storage blob download \
  --account-name YOUR_STORAGE_ACCOUNT \
  --container-name elephant-archive \
  --name file.txt \
  --file file.txt
```

### From Application

Managed Identity provides automatic authentication:

```go
import "github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"

credential, _ := azidentity.NewDefaultAzureCredential(nil)
client, _ := azblob.NewClient("https://ACCOUNT.blob.core.windows.net", credential, nil)
```

## Operations

### Scale Cluster

```bash
# Scale node pool
az aks scale \
  --resource-group dev-elephant-rg \
  --name dev-elephant-aks \
  --node-count 3
```

### Database Backup

```bash
# List backups
az postgres flexible-server backup list \
  --resource-group dev-elephant-rg \
  --name dev-elephant-postgres

# Restore from backup
az postgres flexible-server restore \
  --resource-group dev-elephant-rg \
  --name dev-elephant-postgres-restored \
  --source-server dev-elephant-postgres \
  --restore-time "2024-02-26T10:00:00Z"
```

### View Logs

```bash
# AKS logs
az monitor log-analytics query \
  --workspace dev-elephant-logs \
  --analytics-query "ContainerLog | limit 50"

# PostgreSQL logs
az postgres flexible-server server-logs list \
  --resource-group dev-elephant-rg \
  --name dev-elephant-postgres
```

### Monitoring

```bash
# Open Azure Portal
az portal

# View metrics
az monitor metrics list \
  --resource dev-elephant-aks \
  --resource-group dev-elephant-rg \
  --resource-type Microsoft.ContainerService/managedClusters
```

## Cost Optimization

### Development

- Use Burstable database tier: `db_sku_name = "B_Standard_B2s"`
- Smaller VMs: `vm_size = "Standard_D2s_v3"`
- Fewer nodes: `node_count = 1`
- LRS storage: `storage_replication_type = "LRS"`

### Production

- Use Azure Reserved Instances (1-3 year commitment)
- Enable autoscaling
- Use Azure Hybrid Benefit if you have licenses
- Archive old data to Cool/Archive tier

## Security

### Network Security

- Private AKS cluster option
- Network security groups
- Azure Firewall integration
- Private endpoints for services

### Data Security

- PostgreSQL with SSL/TLS required
- Storage encryption at rest
- Key Vault for secrets
- Managed identities (no credentials)

### Access Control

- Azure RBAC for resource access
- Kubernetes RBAC for cluster access
- Azure Policy for compliance
- Activity logs and audit trails

## Troubleshooting

### AKS Connection Issues

```bash
# Check cluster status
az aks show \
  --resource-group dev-elephant-rg \
  --name dev-elephant-aks

# Get credentials again
az aks get-credentials \
  --resource-group dev-elephant-rg \
  --name dev-elephant-aks \
  --overwrite-existing

# Check network
az network vnet show \
  --resource-group dev-elephant-rg \
  --name dev-elephant-vnet
```

### Database Connection Issues

```bash
# Check PostgreSQL status
az postgres flexible-server show \
  --resource-group dev-elephant-rg \
  --name dev-elephant-postgres

# Test connectivity from AKS
kubectl run -it --rm debug --image=postgres:16-alpine --restart=Never -- \
  psql -h FQDN -U elephant_admin -d elephant
```

### Permission Issues

```bash
# Check role assignments
az role assignment list \
  --assignee YOUR_MANAGED_IDENTITY_ID

# Check Key Vault access
az keyvault show \
  --name dev-elephant-kv \
  --resource-group dev-elephant-rg
```

## Cleanup

### Destroy Infrastructure

```bash
# Destroy all resources
terraform destroy -var-file=environments/dev.tfvars

# Confirm deletion
```

**Warning**: This deletes all data. Backup first!

### Manual Cleanup

If Terraform fails to destroy:

```bash
# Delete resource group (deletes everything)
az group delete --name dev-elephant-rg --yes --no-wait
```

## Cost Estimates

### Development (~$250-350/month)

- AKS: ~$150/month (2 nodes, Standard_D4s_v3)
- PostgreSQL: ~$60/month (Burstable tier)
- Storage: ~$20/month (LRS, 100GB)
- Log Analytics: ~$20/month
- Key Vault: ~$5/month

### Production (~$1000-1500/month)

- AKS: ~$700/month (3-10 nodes, Standard_D8s_v3)
- PostgreSQL: ~$400/month (HA, GP_Standard_D4s_v3)
- Storage: ~$100/month (GRS, 500GB)
- Log Analytics: ~$50/month
- Key Vault: ~$10/month

## Next Steps

1. **Configure DNS**: Use Azure DNS or custom domain
2. **Setup SSL**: Use Azure Application Gateway with SSL
3. **Enable Monitoring**: Azure Monitor and Application Insights
4. **Configure Backups**: Automated backup policies
5. **Setup CI/CD**: Deploy from Azure DevOps or GitHub Actions

## See Also

- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [PostgreSQL Documentation](https://docs.microsoft.com/en-us/azure/postgresql/)
- [Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
