# Terraform Infrastructure

Production-ready Terraform configurations for deploying Elephant to AWS, GCP, or Azure.

## Cloud Provider Options

Choose the cloud provider that best fits your needs:

| Provider | Directory | Best For | Dev Cost | Prod Cost | Guide |
|----------|-----------|----------|----------|-----------|-------|
| **AWS** | [aws/](aws/) | Mature ecosystem, wide service selection | ~$200/mo | ~$800-1500/mo | [AWS README](aws/README.md) |
| **GCP** | [gcp/](gcp/) | Kubernetes-native, competitive pricing | ~$200-300/mo | ~$800-1200/mo | [GCP README](gcp/README.md) |
| **Azure** | [azure/](azure/) | Enterprise integration, hybrid cloud | ~$250-350/mo | ~$1000-1500/mo | [Azure README](azure/README.md) |

### Quick Decision Guide

- **Already using AWS?** → Use [AWS](aws/) - Most mature, widest service selection
- **Kubernetes-first approach?** → Use [GCP](gcp/) - Best GKE experience, Workload Identity
- **Microsoft ecosystem?** → Use [Azure](azure/) - Seamless integration with Microsoft services
- **Best pricing?** → Compare all three for your specific region and usage

**Need help choosing?** See the [detailed comparison guide](COMPARISON.md).

## What Gets Created

All configurations provide equivalent infrastructure:

### Compute
- **AWS**: EKS (Elastic Kubernetes Service)
- **GCP**: GKE (Google Kubernetes Engine)
- **Azure**: AKS (Azure Kubernetes Service)

### Database
- **AWS**: RDS PostgreSQL 16
- **GCP**: Cloud SQL PostgreSQL 16
- **Azure**: Azure Database for PostgreSQL Flexible Server 16

### Storage
- **AWS**: S3 with lifecycle policies
- **GCP**: Cloud Storage with lifecycle management
- **Azure**: Blob Storage with versioning

### Networking
- **AWS**: VPC with public/private subnets
- **GCP**: VPC with Cloud NAT
- **Azure**: VNet with subnets

### Security
- **AWS**: IAM roles with IRSA, Secrets Manager
- **GCP**: Workload Identity, Secret Manager
- **Azure**: Managed Identity, Key Vault

### Monitoring
- **AWS**: CloudWatch
- **GCP**: Cloud Monitoring & Logging
- **Azure**: Log Analytics & Azure Monitor

## Prerequisites

### All Providers

- Terraform 1.5 or later
- kubectl for Kubernetes management
- Active cloud account with billing enabled

### Provider-Specific

**AWS**:
```bash
# Install AWS CLI
brew install awscli

# Configure
aws configure
```

**GCP**:
```bash
# Install gcloud
brew install google-cloud-sdk

# Login
gcloud auth login
gcloud auth application-default login
```

**Azure**:
```bash
# Install Azure CLI
brew install azure-cli

# Login
az login
```

## Quick Start

### 1. Choose Your Cloud

```bash
# AWS
cd elephant-handbook/terraform/aws

# GCP
cd elephant-handbook/terraform/gcp

# Azure
cd elephant-handbook/terraform/azure
```

### 2. Configure Variables

```bash
# Copy example
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

### 3. Deploy

```bash
# Initialize
terraform init

# Plan (review changes)
terraform plan -var-file=environments/dev.tfvars

# Apply (create resources)
terraform apply -var-file=environments/dev.tfvars
```

Takes 15-20 minutes.

### 4. Configure kubectl

```bash
# AWS
aws eks update-kubeconfig --region REGION --name CLUSTER_NAME

# GCP
gcloud container clusters get-credentials CLUSTER_NAME --region REGION

# Azure
az aks get-credentials --resource-group RG_NAME --name CLUSTER_NAME
```

### 5. Deploy Elephant

```bash
# Deploy to Kubernetes
kubectl apply -k ../../kubernetes/base

# Watch deployment
kubectl get pods -n elephant -w
```

## Environment Configurations

Each provider includes two environment configurations:

### Development
- Lower cost (~$200-350/month)
- Single availability zone
- Smaller instance sizes
- Reduced redundancy
- Perfect for testing and development

### Production
- High availability (~$800-1500/month)
- Multi-zone deployment
- Larger instance sizes
- Automated backups
- Geo-redundant storage
- Production-ready security

## Feature Comparison

| Feature | AWS | GCP | Azure |
|---------|-----|-----|-------|
| **Kubernetes** | EKS | GKE (best) | AKS |
| **Database HA** | Multi-AZ | Regional | Zone-redundant |
| **Auto-scaling** | ✓ | ✓ | ✓ |
| **Managed Identity** | IRSA | Workload Identity | Managed Identity |
| **Secret Management** | Secrets Manager | Secret Manager | Key Vault |
| **Backup Automation** | ✓ | ✓ | ✓ |
| **Encryption** | KMS | Cloud KMS | Key Vault |
| **Monitoring** | CloudWatch | Cloud Monitoring | Azure Monitor |
| **Cost Management** | Cost Explorer | Cost Management | Cost Management |

## Cost Optimization Tips

### All Providers

1. **Use spot/preemptible instances** for non-critical workloads
2. **Enable autoscaling** to match demand
3. **Use committed use discounts** (1-3 year terms)
4. **Archive old data** to cheaper storage tiers
5. **Right-size instances** based on actual usage
6. **Delete unused resources** regularly

### Provider-Specific

**AWS**:
- Use Savings Plans
- Reserved Instances for predictable workloads
- S3 Intelligent-Tiering

**GCP**:
- Committed use discounts
- Sustained use discounts (automatic)
- Spot VMs for dev/test

**Azure**:
- Azure Reserved Instances
- Azure Hybrid Benefit (if you have licenses)
- Burstable database tiers for dev

## Security Best Practices

### All Configurations Include

- ✓ Private Kubernetes nodes
- ✓ Database in private subnet
- ✓ Encryption at rest
- ✓ Encryption in transit (TLS)
- ✓ Managed identities (no credentials)
- ✓ Network isolation
- ✓ Automated backups
- ✓ Audit logging

### Additional Recommendations

1. **Enable MFA** on cloud accounts
2. **Use separate accounts** for dev/staging/prod
3. **Implement least privilege** IAM policies
4. **Enable security scanning** for containers
5. **Set up alerts** for suspicious activity
6. **Regular security audits**
7. **Rotate credentials** regularly

## Operations

### Common Tasks

**Scale cluster**:
```bash
# AWS
aws eks update-nodegroup-config --cluster-name NAME --nodegroup-name NAME --scaling-config desiredSize=3

# GCP
gcloud container clusters resize CLUSTER --num-nodes 3 --region REGION

# Azure
az aks scale --resource-group RG --name CLUSTER --node-count 3
```

**View logs**:
```bash
# All providers (Kubernetes)
kubectl logs -n elephant -l app=elephant-repository -f

# Provider-specific logging tools also available
```

**Database backup**:
```bash
# AWS
aws rds create-db-snapshot --db-instance-identifier ID --db-snapshot-identifier SNAPSHOT

# GCP
gcloud sql backups create --instance INSTANCE

# Azure
az postgres flexible-server backup create --resource-group RG --name SERVER
```

## Troubleshooting

### Connection Issues

```bash
# Check cluster status
kubectl get nodes

# Check pods
kubectl get pods -n elephant

# Check events
kubectl get events -n elephant --sort-by='.lastTimestamp'
```

### Database Issues

```bash
# Test connectivity
kubectl run -it --rm debug --image=postgres:16-alpine --restart=Never -n elephant -- \
  psql -h DATABASE_HOST -U USERNAME -d elephant
```

### Permission Issues

Check provider-specific IAM/RBAC:
- AWS: IAM roles and policies
- GCP: IAM bindings and service accounts
- Azure: Role assignments and managed identities

## Cleanup

### Destroy Infrastructure

```bash
# From provider directory
terraform destroy -var-file=environments/dev.tfvars
```

**⚠️ Warning**: This deletes all resources and data. Backup first!

### Verify Deletion

Check cloud console to ensure all resources are deleted to avoid unexpected charges.

## Migration Between Clouds

To migrate Elephant between cloud providers:

1. **Backup data**: Export PostgreSQL database and storage
2. **Deploy new infrastructure**: Use Terraform for target cloud
3. **Restore data**: Import to new database and storage
4. **Update DNS**: Point to new load balancer
5. **Verify**: Test all functionality
6. **Cleanup**: Destroy old infrastructure

## Cost Estimates

### Development Environment

| Provider | Monthly Cost | Notes |
|----------|--------------|-------|
| AWS | ~$200 | t3.medium nodes, db.t3.medium |
| GCP | ~$200-300 | e2-standard-4, spot instances |
| Azure | ~$250-350 | Standard_D4s_v3, burstable DB |

### Production Environment

| Provider | Monthly Cost | Notes |
|----------|--------------|-------|
| AWS | ~$800-1500 | m5.xlarge nodes, Multi-AZ |
| GCP | ~$800-1200 | e2-standard-8, regional HA |
| Azure | ~$1000-1500 | Standard_D8s_v3, zone-redundant |

Costs vary by region, usage, and specific configuration.

## Next Steps

1. **Choose your cloud provider** based on requirements
2. **Review provider-specific README** for detailed instructions
3. **Deploy development environment** first
4. **Test thoroughly** before production
5. **Set up monitoring and alerts**
6. **Configure backups and disaster recovery**
7. **Document your configuration**

## Support

- [AWS Terraform Guide](aws/README.md)
- [GCP Terraform Guide](gcp/README.md)
- [Azure Terraform Guide](azure/README.md)
- [Kubernetes Deployment](../kubernetes/README.md)
- [Docker Compose (Local)](../docker-compose/README.md)

## See Also

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
