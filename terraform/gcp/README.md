# Elephant on Google Cloud Platform (GCP)

Deploy Elephant to GCP using Terraform with GKE, Cloud SQL, and Cloud Storage.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      GCP Project                            │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              VPC Network                             │  │
│  │                                                      │  │
│  │  ┌────────────────────────────────────────────┐    │  │
│  │  │         GKE Cluster (Regional)             │    │  │
│  │  │                                            │    │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐│    │  │
│  │  │  │  Node    │  │  Node    │  │  Node    ││    │  │
│  │  │  │ (zone-b) │  │ (zone-c) │  │ (zone-d) ││    │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘│    │  │
│  │  │                                            │    │  │
│  │  │  Workload Identity enabled                │    │  │
│  │  └────────────────────────────────────────────┘    │  │
│  │                                                      │  │
│  │  ┌────────────────────────────────────────────┐    │  │
│  │  │      Cloud SQL PostgreSQL 16               │    │  │
│  │  │      (Private IP, Automated Backups)       │    │  │
│  │  └────────────────────────────────────────────┘    │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │      Cloud Storage Bucket                            │  │
│  │      (Versioning, Lifecycle Management)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │      Secret Manager                                  │  │
│  │      (Database credentials, API keys)                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **GKE Regional Cluster**: Multi-zone for high availability
- **Cloud SQL PostgreSQL 16**: Managed database with automated backups
- **Cloud Storage**: Object storage with versioning and lifecycle policies
- **Workload Identity**: Secure service account authentication
- **Private Networking**: VPC-native cluster with private nodes
- **Cloud NAT**: Outbound internet access for private nodes
- **Secret Manager**: Secure credential storage
- **Optional CMEK**: Customer-managed encryption keys

## Prerequisites

1. **GCP Account** with billing enabled
2. **gcloud CLI** installed and configured
3. **Terraform** 1.5 or later
4. **kubectl** for Kubernetes management

### Install Tools

```bash
# macOS
brew install google-cloud-sdk terraform kubectl

# Verify
gcloud version
terraform version
kubectl version --client
```

### Configure gcloud

```bash
# Login
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable \
  container.googleapis.com \
  sqladmin.googleapis.com \
  storage.googleapis.com \
  secretmanager.googleapis.com \
  servicenetworking.googleapis.com
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
project_id  = "your-gcp-project-id"
region      = "europe-west1"
environment = "dev"
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
gcloud container clusters get-credentials dev-elephant-gke \
  --region europe-west1 \
  --project YOUR_PROJECT_ID

# Verify
kubectl get nodes
```

### 4. Deploy Elephant

```bash
# Deploy to GKE
kubectl apply -k ../../kubernetes/base

# Watch deployment
kubectl get pods -n elephant -w
```

## Configuration

### Environment Files

- `environments/dev.tfvars` - Development (~$200-300/month)
- `environments/production.tfvars` - Production (~$800-1200/month)

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | Required |
| `region` | GCP region | europe-west1 |
| `machine_type` | GKE node type | e2-standard-4 |
| `node_count_per_zone` | Nodes per zone | 1 |
| `db_tier` | Cloud SQL tier | db-custom-2-8192 |
| `use_spot_instances` | Use spot VMs | false |

### Network Configuration

```hcl
subnet_cidr    = "10.0.0.0/20"    # Node subnet
pods_cidr      = "10.4.0.0/14"    # Pod IPs
services_cidr  = "10.8.0.0/20"    # Service IPs
master_cidr    = "172.16.0.0/28"  # GKE master
```

## Workload Identity Setup

Elephant uses Workload Identity to access GCP services securely.

### Configure Kubernetes Service Account

```bash
# Create namespace
kubectl create namespace elephant

# Create service account
kubectl create serviceaccount elephant-repository -n elephant

# Annotate with GCP service account
kubectl annotate serviceaccount elephant-repository \
  -n elephant \
  iam.gke.io/gcp-service-account=dev-elephant-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

### Use in Deployment

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: elephant-repository
  namespace: elephant
spec:
  serviceAccountName: elephant-repository
  containers:
  - name: app
    image: ghcr.io/dimelords/elephant-repository:latest
    env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /var/run/secrets/workload-identity/token
```

## Database Connection

### Connection String

```bash
# Get connection details
terraform output database_connection_name
terraform output database_private_ip

# Connection string format
postgresql://elephant_app:PASSWORD@PRIVATE_IP:5432/elephant
```

### Cloud SQL Proxy (Optional)

```bash
# Download proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.darwin.amd64
chmod +x cloud-sql-proxy

# Run proxy
./cloud-sql-proxy --private-ip YOUR_CONNECTION_NAME
```

## Storage Access

### Using gsutil

```bash
# List buckets
gsutil ls

# Upload file
gsutil cp file.txt gs://YOUR_BUCKET/

# Download file
gsutil cp gs://YOUR_BUCKET/file.txt .
```

### From Application

Workload Identity provides automatic authentication:

```go
import "cloud.google.com/go/storage"

client, err := storage.NewClient(ctx)
bucket := client.Bucket("your-bucket-name")
```

## Operations

### Scale Cluster

```bash
# Scale node pool
gcloud container clusters resize dev-elephant-gke \
  --region europe-west1 \
  --num-nodes 2 \
  --node-pool dev-elephant-nodes
```

### Database Backup

```bash
# List backups
gcloud sql backups list --instance=dev-elephant-postgres

# Create manual backup
gcloud sql backups create --instance=dev-elephant-postgres

# Restore from backup
gcloud sql backups restore BACKUP_ID \
  --backup-instance=dev-elephant-postgres \
  --backup-instance=dev-elephant-postgres
```

### View Logs

```bash
# GKE logs
gcloud logging read "resource.type=k8s_cluster" --limit 50

# Cloud SQL logs
gcloud logging read "resource.type=cloudsql_database" --limit 50
```

### Monitoring

```bash
# Open Cloud Console
gcloud console

# View metrics
gcloud monitoring dashboards list
```

## Cost Optimization

### Development

- Use spot instances: `use_spot_instances = true`
- Smaller machine types: `machine_type = "e2-standard-2"`
- Single zone: `node_count_per_zone = 1`
- Smaller database: `db_tier = "db-custom-1-3840"`

### Production

- Use committed use discounts
- Enable autoscaling: `min_node_count` and `max_node_count`
- Use regional persistent disks
- Archive old data to Coldline storage

## Security

### Network Security

- Private GKE nodes (no public IPs)
- Cloud NAT for outbound traffic
- Authorized networks for master access
- VPC-native cluster with network policies

### Data Security

- Cloud SQL with private IP only
- SSL/TLS required for database connections
- Storage bucket with uniform access control
- Optional CMEK for encryption

### Access Control

- Workload Identity (no service account keys)
- IAM roles with least privilege
- Secret Manager for sensitive data
- Audit logging enabled

## Troubleshooting

### GKE Connection Issues

```bash
# Check cluster status
gcloud container clusters describe dev-elephant-gke --region europe-west1

# Get credentials again
gcloud container clusters get-credentials dev-elephant-gke \
  --region europe-west1

# Check firewall rules
gcloud compute firewall-rules list
```

### Database Connection Issues

```bash
# Check Cloud SQL status
gcloud sql instances describe dev-elephant-postgres

# Test connectivity from GKE
kubectl run -it --rm debug --image=postgres:16-alpine --restart=Never -- \
  psql -h PRIVATE_IP -U elephant_app -d elephant
```

### Permission Issues

```bash
# Check IAM bindings
gcloud projects get-iam-policy YOUR_PROJECT_ID

# Check service account permissions
gcloud iam service-accounts get-iam-policy \
  dev-elephant-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
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
# Delete GKE cluster
gcloud container clusters delete dev-elephant-gke --region europe-west1

# Delete Cloud SQL
gcloud sql instances delete dev-elephant-postgres

# Delete storage bucket
gsutil rm -r gs://YOUR_BUCKET
```

## Cost Estimates

### Development (~$200-300/month)

- GKE: ~$150/month (3 nodes with spot instances)
- Cloud SQL: ~$80/month (db-custom-2-8192, zonal)
- Storage: ~$10/month (100GB standard)
- Networking: ~$20/month

### Production (~$800-1200/month)

- GKE: ~$600/month (6-15 nodes, regular instances)
- Cloud SQL: ~$350/month (db-custom-4-16384, regional HA)
- Storage: ~$50/month (500GB with lifecycle)
- Networking: ~$50/month
- KMS: ~$5/month

## Next Steps

1. **Configure DNS**: Point domain to load balancer
2. **Setup SSL**: Use Google-managed certificates
3. **Enable Monitoring**: Cloud Monitoring and Logging
4. **Configure Backups**: Automated backup schedule
5. **Setup CI/CD**: Deploy from Cloud Build

## See Also

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
