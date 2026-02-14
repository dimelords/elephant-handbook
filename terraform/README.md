# Terraform Infrastructure

Infrastructure as Code for deploying Elephant on cloud providers.

## Directory Structure

```
terraform/
├── aws/                    # AWS infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/
│       ├── rds/
│       ├── s3/
│       ├── opensearch/
│       └── eks/
├── gcp/                    # GCP infrastructure
│   ├── main.tf
│   ├── variables.tf
│   └── modules/
└── shared/                 # Shared modules
    ├── monitoring/
    └── secrets/
```

## AWS Deployment

### Prerequisites

- AWS CLI configured
- Terraform 1.5+
- Appropriate AWS permissions

### Quick Start

```bash
cd terraform/aws

# Initialize
terraform init

# Plan
terraform plan -var-file=environments/production.tfvars

# Apply
terraform apply -var-file=environments/production.tfvars
```

### What Gets Created

**Network**
- VPC with public and private subnets
- NAT Gateways
- Security Groups
- Load Balancers

**Compute**
- EKS cluster with node groups
- Auto-scaling groups

**Storage**
- RDS PostgreSQL 16 (Multi-AZ)
- S3 buckets for archives
- EBS volumes

**Search**
- AWS OpenSearch Service

**Monitoring**
- CloudWatch Log Groups
- CloudWatch Alarms
- SNS Topics for alerts

**Security**
- IAM Roles and Policies
- Secrets Manager for credentials
- ACM certificates

### Cost Estimate

**Development** (~$200/month)
- EKS: $73/month (control plane)
- RDS: db.t3.medium (~$60/month)
- OpenSearch: t3.small (~$30/month)
- Data transfer & storage: ~$37/month

**Production** (~$800-1500/month)
- EKS: $73/month (control plane)
- RDS: db.r5.xlarge Multi-AZ (~$400/month)
- OpenSearch: r5.large 3-node (~$400/month)
- S3: ~$50/month
- Data transfer: ~$100/month
- Compute nodes: $300-500/month

## GCP Deployment

### Prerequisites

- gcloud CLI configured
- Terraform 1.5+
- GCP project with billing enabled

### Quick Start

```bash
cd terraform/gcp

# Initialize
terraform init

# Plan
terraform plan -var-file=environments/production.tfvars

# Apply
terraform apply -var-file=environments/production.tfvars
```

### What Gets Created

**Network**
- VPC with subnets
- Cloud NAT
- Firewall rules
- Load Balancers

**Compute**
- GKE cluster with node pools
- Auto-scaling enabled

**Storage**
- Cloud SQL PostgreSQL 16
- Cloud Storage buckets
- Persistent Disks

**Search**
- Self-managed OpenSearch on GCE

**Monitoring**
- Cloud Logging
- Cloud Monitoring
- Alerting Policies

## Modules

### VPC Module

Creates network infrastructure with best practices:

```hcl
module "vpc" {
  source = "./modules/vpc"

  environment = "production"
  cidr_block  = "10.0.0.0/16"

  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Project = "Elephant"
  }
}
```

### RDS Module

PostgreSQL 16 with Multi-AZ, backups, and monitoring:

```hcl
module "rds" {
  source = "./modules/rds"

  environment       = "production"
  instance_class    = "db.r5.xlarge"
  allocated_storage = 500

  multi_az               = true
  backup_retention_period = 7

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

### S3 Module

S3 buckets with versioning, encryption, and lifecycle policies:

```hcl
module "s3" {
  source = "./modules/s3"

  environment = "production"

  buckets = {
    archive = {
      versioning = true
      lifecycle_rules = [
        {
          transition_days = 90
          storage_class   = "GLACIER"
        }
      ]
    }
  }
}
```

### OpenSearch Module

Managed OpenSearch Service:

```hcl
module "opensearch" {
  source = "./modules/opensearch"

  environment     = "production"
  instance_type   = "r5.large.search"
  instance_count  = 3
  ebs_volume_size = 100

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

### EKS Module

EKS cluster with managed node groups:

```hcl
module "eks" {
  source = "./modules/eks"

  environment    = "production"
  cluster_version = "1.28"

  node_groups = {
    general = {
      instance_types = ["t3.xlarge"]
      min_size       = 2
      max_size       = 10
      desired_size   = 3
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

## Variables

### Common Variables

```hcl
variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "region" {
  description = "AWS/GCP region"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
```

### Environment-Specific

Create `environments/production.tfvars`:

```hcl
environment = "production"
region      = "us-east-1"

# Database
db_instance_class    = "db.r5.xlarge"
db_allocated_storage = 500
db_multi_az          = true

# OpenSearch
opensearch_instance_type  = "r5.large.search"
opensearch_instance_count = 3

# EKS
eks_node_instance_types = ["t3.xlarge"]
eks_node_min_size       = 3
eks_node_max_size       = 10

tags = {
  Project     = "Elephant"
  Environment = "production"
  ManagedBy   = "Terraform"
}
```

## Outputs

Terraform outputs provide connection information:

```hcl
output "rds_endpoint" {
  description = "PostgreSQL connection endpoint"
  value       = module.rds.endpoint
}

output "s3_bucket_archive" {
  description = "S3 archive bucket name"
  value       = module.s3.bucket_names["archive"]
}

output "opensearch_endpoint" {
  description = "OpenSearch endpoint"
  value       = module.opensearch.endpoint
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}
```

## State Management

### Remote State (S3 Backend)

```hcl
terraform {
  backend "s3" {
    bucket         = "elephant-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### State Locking

Create DynamoDB table for state locking:

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Security Best Practices

1. **Secrets**: Use AWS Secrets Manager or GCP Secret Manager
2. **IAM**: Principle of least privilege
3. **Encryption**: Enable at-rest and in-transit encryption
4. **Network**: Use private subnets for databases
5. **Logging**: Enable audit logs and CloudTrail
6. **Backups**: Automated backups with retention policies

## Disaster Recovery

### RDS Backups

- Automated daily backups (7-day retention)
- Point-in-time recovery enabled
- Cross-region snapshots for production

### S3 Versioning

- Versioning enabled on archive buckets
- Lifecycle policies for cost optimization
- Cross-region replication (optional)

### EKS Backups

- Velero for cluster backup
- Regular etcd snapshots
- Infrastructure as Code for rebuild

## Monitoring and Alerting

### CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "elephant-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### SNS Topics

```hcl
resource "aws_sns_topic" "alerts" {
  name = "elephant-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "ops@example.com"
}
```

## Multi-Environment Setup

```
terraform/
├── environments/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── production.tfvars
└── workspaces/
    ├── dev/
    ├── staging/
    └── production/
```

Use Terraform workspaces:

```bash
# Create workspace
terraform workspace new production

# Select workspace
terraform workspace select production

# Apply
terraform apply -var-file=environments/production.tfvars
```

## Migration from Manual Setup

1. Import existing resources
2. Generate Terraform configuration
3. Validate with `terraform plan`
4. Apply incrementally

```bash
# Import RDS instance
terraform import module.rds.aws_db_instance.main elephant-db

# Import S3 bucket
terraform import module.s3.aws_s3_bucket.archive elephant-archive
```

## Cleanup

```bash
# Destroy all resources
terraform destroy -var-file=environments/production.tfvars

# Destroy specific module
terraform destroy -target=module.opensearch
```

## Troubleshooting

### State Issues

```bash
# Show state
terraform show

# List resources
terraform state list

# Remove resource from state
terraform state rm module.rds.aws_db_instance.main
```

### Apply Failures

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Target specific resource
terraform apply -target=module.vpc
```

## Further Reading

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
