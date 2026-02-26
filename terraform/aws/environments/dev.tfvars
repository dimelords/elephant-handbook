# Development Environment Configuration

environment  = "dev"
region       = "us-east-1"
project_name = "elephant"

# Network
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Database - Small instance for dev
db_instance_class           = "db.t3.medium"
db_allocated_storage        = 50
db_max_allocated_storage    = 200
db_backup_retention_period  = 3
db_multi_az                 = false

# EKS - Minimal for dev
eks_cluster_version     = "1.28"
eks_node_instance_types = ["t3.medium"]
eks_node_desired_size   = 2
eks_node_min_size       = 1
eks_node_max_size       = 4

# S3 - Faster transitions for dev
s3_archive_lifecycle_glacier_days      = 30
s3_archive_lifecycle_deep_archive_days = 90

# OpenSearch - Single node for dev
opensearch_instance_type   = "t3.small.search"
opensearch_instance_count  = 1
opensearch_ebs_volume_size = 50

# Monitoring
enable_cloudwatch_logs = true
log_retention_days     = 7

# Secrets
enable_secrets_rotation = false

# Tags
common_tags = {
  Project     = "Elephant"
  Environment = "dev"
  ManagedBy   = "Terraform"
}
