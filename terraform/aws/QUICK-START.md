# Elephant AWS Quick Start

Deploy Elephant to AWS in 15 minutes.

## Prerequisites

```bash
# Check AWS CLI
aws sts get-caller-identity

# Check Terraform
terraform version  # Should be 1.5+

# Check kubectl
kubectl version --client
```

## Step 1: Configure Variables

```bash
cd elephant-handbook/terraform/aws

# Copy example
cp terraform.tfvars.example terraform.tfvars

# Edit for your environment
vim terraform.tfvars
```

Minimal configuration:

```hcl
environment = "dev"
region      = "us-east-1"
```

## Step 2: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Deploy (takes ~15 minutes)
terraform apply

# Type 'yes' to confirm
```

## Step 3: Configure kubectl

```bash
# Get command from output
terraform output kubectl_config_command

# Or run directly
aws eks update-kubeconfig --region us-east-1 --name elephant-dev-eks

# Verify
kubectl get nodes
```

## Step 4: Deploy Elephant

```bash
# Deploy Kubernetes manifests
kubectl apply -k ../../kubernetes/base

# Watch deployment
kubectl get pods -n elephant -w

# Wait for all pods to be Running (2-5 minutes)
```

## Step 5: Access Services

```bash
# Port forward to services
kubectl port-forward -n elephant svc/repository 1080:1080 &
kubectl port-forward -n elephant svc/keycloak 8080:8080 &

# Access Keycloak
open http://localhost:8080/admin
# Login: admin/admin
```

## Step 6: Get Connection Info

```bash
# Database endpoint
terraform output rds_endpoint

# S3 bucket
terraform output s3_archive_bucket

# OpenSearch endpoint
terraform output opensearch_endpoint
```

## What Was Created?

- ✅ VPC with public/private subnets
- ✅ RDS PostgreSQL 16 (encrypted)
- ✅ S3 bucket for archives
- ✅ OpenSearch for search
- ✅ EKS cluster with 2-3 nodes
- ✅ IAM roles with IRSA
- ✅ Secrets Manager for DB credentials
- ✅ CloudWatch logs

## Cost

Development environment: **~$200-300/month**

- EKS: $73/month
- RDS: ~$60/month
- OpenSearch: ~$30/month
- Compute: ~$60/month
- Networking: ~$30/month

## Next Steps

1. **Configure Keycloak**: Create realm and users
2. **Load Schemas**: Use eleconf to configure document types
3. **Deploy Frontend**: Add elephant-chrome to EKS
4. **Set Up DNS**: Configure Route53 or external DNS
5. **Enable TLS**: Use cert-manager and Let's Encrypt

## Cleanup

```bash
# Delete Kubernetes resources first
kubectl delete namespace elephant

# Then destroy infrastructure
terraform destroy

# Type 'yes' to confirm
```

## Troubleshooting

### Can't connect to EKS

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name elephant-dev-eks

# Check IAM permissions
aws sts get-caller-identity
```

### Pods not starting

```bash
# Check pod status
kubectl get pods -n elephant

# View logs
kubectl logs -n elephant <pod-name>

# Describe pod
kubectl describe pod -n elephant <pod-name>
```

### Terraform errors

```bash
# Enable debug logging
export TF_LOG=DEBUG

# Refresh state
terraform refresh

# Show state
terraform show
```

## See Also

- [Full README](../README.md) - Complete documentation
- [Kubernetes Guide](../../kubernetes/README.md) - Deploy to EKS
- [Configuration](../../docs/configuration/) - Schema setup
