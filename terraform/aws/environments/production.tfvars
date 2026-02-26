# Production Environment Configuration

environment  = "production"
region       = "us-east-1"
project_name = "elephant"

# Network - 3 AZs for high availability
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Database - Production-grade with Multi-AZ
db_instance_class           = "db.r5.xlarge"
db_allocated_storage        = 500
db_max_allocated_storage    = 2000
db_backup_retention_period  = 30
db_multi_az                 = true

# EKS - Production capacity
eks_cluster_version     = "1.28"
eks_node_instance_types = ["t3.xlarge"]
eks_node_desired_size   = 5
eks_node_min_size       = 3
eks_node_max_size       = 20

# S3 - Standard lifecycle
s3_archive_lifecycle_glacier_days      = 90
s3_archive_lifecycle_deep_archive_days = 365

# OpenSearch - 3-node cluster for HA
opensearch_instance_type   = "r5.large.search"
opensearch_instance_count  = 3
opensearch_ebs_volume_size = 200

# Monitoring
enable_cloudwatch_logs = true
log_retention_days     = 90

# Secrets
enable_secrets_rotation = true

# Tags
common_tags = {
  Project     = "Elephant"
  Environment = "production"
  ManagedBy   = "Terraform"
  Compliance  = "required"
}
