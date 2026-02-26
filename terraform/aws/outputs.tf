# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "rds_secret_arn" {
  description = "ARN of secret containing RDS credentials"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

# S3 Outputs
output "s3_archive_bucket" {
  description = "S3 archive bucket name"
  value       = aws_s3_bucket.archive.id
}

output "s3_archive_bucket_arn" {
  description = "S3 archive bucket ARN"
  value       = aws_s3_bucket.archive.arn
}

# OpenSearch Outputs
output "opensearch_endpoint" {
  description = "OpenSearch endpoint"
  value       = aws_opensearch_domain.main.endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint"
  value       = "https://${aws_opensearch_domain.main.endpoint}/_dashboards"
}

# EKS Outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_certificate_authority" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC provider for EKS"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# IAM Outputs
output "eks_node_role_arn" {
  description = "IAM role ARN for EKS nodes"
  value       = aws_iam_role.eks_node.arn
}

output "elephant_app_role_arn" {
  description = "IAM role ARN for Elephant application (IRSA)"
  value       = aws_iam_role.elephant_app.arn
}

# Connection Information
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.main.name}"
}

output "connection_info" {
  description = "Connection information for services"
  value = {
    rds_endpoint       = aws_db_instance.main.endpoint
    s3_bucket          = aws_s3_bucket.archive.id
    opensearch_endpoint = aws_opensearch_domain.main.endpoint
    eks_cluster        = aws_eks_cluster.main.name
  }
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost (approximate)"
  value = {
    eks_control_plane = "$73"
    rds              = var.db_instance_class == "db.t3.medium" ? "~$60" : "~$400"
    opensearch       = var.opensearch_instance_type == "t3.medium.search" ? "~$30" : "~$400"
    s3               = "~$20-50 (depends on usage)"
    data_transfer    = "~$50-100 (depends on usage)"
    total_estimate   = var.environment == "production" ? "~$800-1500/month" : "~$200-300/month"
  }
}
