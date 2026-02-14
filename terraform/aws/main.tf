terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "elephant-terraform-state"
    key            = "elephant/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.common_tags, {
      ManagedBy   = "Terraform"
      Project     = "Elephant"
      Environment = var.environment
    })
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  enable_nat_gateway = true
  single_nat_gateway = var.environment != "production"
}

# RDS PostgreSQL Module
module "rds" {
  source = "./modules/rds"

  environment = var.environment

  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage

  database_name = "elephant"
  username      = "elephant"
  # Password managed via AWS Secrets Manager

  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.vpc.database_security_group_id]

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled = var.environment == "production"
}

# S3 Buckets Module
module "s3" {
  source = "./modules/s3"

  environment = var.environment

  buckets = {
    archive = {
      versioning = true
      lifecycle_rules = [
        {
          id                = "archive-transition"
          enabled           = true
          transition_days   = 90
          storage_class     = "GLACIER"
        },
        {
          id                = "deep-archive-transition"
          enabled           = true
          transition_days   = 365
          storage_class     = "DEEP_ARCHIVE"
        }
      ]
    }
    reports = {
      versioning = false
      lifecycle_rules = [
        {
          id              = "cleanup-old-reports"
          enabled         = true
          expiration_days = 30
        }
      ]
    }
  }
}

# OpenSearch Service Module
module "opensearch" {
  source = "./modules/opensearch"

  environment = var.environment

  domain_name    = "elephant-${var.environment}"
  engine_version = "OpenSearch_2.11"

  instance_type  = var.opensearch_instance_type
  instance_count = var.opensearch_instance_count

  ebs_enabled     = true
  ebs_volume_size = var.opensearch_ebs_volume_size
  ebs_volume_type = "gp3"

  zone_awareness_enabled = var.opensearch_instance_count > 1

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = slice(module.vpc.private_subnet_ids, 0, min(2, length(module.vpc.private_subnet_ids)))
  security_group_ids  = [module.vpc.opensearch_security_group_id]

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }
}

# EKS Cluster Module
module "eks" {
  source = "./modules/eks"

  environment    = var.environment
  cluster_name   = "elephant-${var.environment}"
  cluster_version = var.eks_cluster_version

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.public_subnet_ids

  enable_irsa = true # IAM Roles for Service Accounts

  node_groups = {
    general = {
      name           = "general"
      instance_types = var.eks_node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      disk_size = 50

      labels = {
        role = "general"
      }

      taints = []

      tags = {
        NodeGroup = "general"
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}

# Secrets Manager for sensitive values
resource "aws_secretsmanager_secret" "db_password" {
  name = "elephant-${var.environment}-db-password"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "jwt_signing_key" {
  name = "elephant-${var.environment}-jwt-signing-key"

  lifecycle {
    prevent_destroy = true
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/elephant/${var.environment}"
  retention_in_days = var.environment == "production" ? 30 : 7
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "elephant-${var.environment}-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "elephant-${var.environment}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "elephant-${var.environment}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS connection count is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }
}

# CloudWatch Alarms for OpenSearch
resource "aws_cloudwatch_metric_alarm" "opensearch_cpu" {
  alarm_name          = "elephant-${var.environment}-opensearch-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "OpenSearch CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DomainName = module.opensearch.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }
}

resource "aws_cloudwatch_metric_alarm" "opensearch_cluster_red" {
  alarm_name          = "elephant-${var.environment}-opensearch-cluster-red"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ClusterStatus.red"
  namespace           = "AWS/ES"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "OpenSearch cluster status is RED"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = module.opensearch.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
