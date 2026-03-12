###############################################################################
# Staging environment – ON_DEMAND nodes, moderate sizing, 7-day backups
###############################################################################

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  region   = var.region
  vpc_name = "${var.project_name}-${var.environment}"
  vpc_cidr = "10.1.0.0/16"

  availability_zones   = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  roles = {
    "${var.project_name}-${var.environment}-eks-cluster" = {
      description = "EKS cluster role for ${var.environment}"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Service = "eks.amazonaws.com" }
          Action    = "sts:AssumeRole"
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
      ]
    }

    "${var.project_name}-${var.environment}-eks-nodes" = {
      description = "EKS node group role for ${var.environment}"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Service = "ec2.amazonaws.com" }
          Action    = "sts:AssumeRole"
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
      ]
      create_instance_profile = true
    }

    "${var.project_name}-${var.environment}-ecs-execution" = {
      description = "ECS task execution role for ${var.environment}"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Service = "ecs-tasks.amazonaws.com" }
          Action    = "sts:AssumeRole"
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
      ]
    }

    "${var.project_name}-${var.environment}-ecs-task" = {
      description = "ECS task role for ${var.environment}"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Service = "ecs-tasks.amazonaws.com" }
          Action    = "sts:AssumeRole"
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
      ]
    }

    "${var.project_name}-${var.environment}-lambda" = {
      description = "Lambda execution role for ${var.environment}"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Service = "lambda.amazonaws.com" }
          Action    = "sts:AssumeRole"
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
        "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
      ]
    }

    "${var.project_name}-${var.environment}-sagemaker" = {
      description = "SageMaker execution role for ${var.environment}"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Service = "sagemaker.amazonaws.com" }
          Action    = "sts:AssumeRole"
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess",
      ]
    }
  }

  tags = local.tags
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
module "secrets_manager" {
  source = "../../modules/secrets-manager"

  secrets = {
    "${var.project_name}/${var.environment}/db-password" = {
      description = "RDS master password for ${var.environment}"
      value       = null
    }
    "${var.project_name}/${var.environment}/api-key" = {
      description = "API key for ${var.environment}"
      value       = null
    }
    "${var.project_name}/${var.environment}/slack-webhook" = {
      description = "Slack webhook URL for ${var.environment} alerts"
      value       = null
    }
  }

  recovery_window_in_days = 7

  tags = local.tags
}

# ── EKS ───────────────────────────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  cluster_role_arn = module.iam.role_arns["${var.project_name}-${var.environment}-eks-cluster"]
  node_role_arn    = module.iam.role_arns["${var.project_name}-${var.environment}-eks-nodes"]

  # Staging: ON_DEMAND, t3.large, 2-5 nodes
  node_instance_types = ["t3.large"]
  capacity_type       = "ON_DEMAND"
  node_desired_size   = 2
  node_min_size       = 2
  node_max_size       = 5
  node_disk_size      = 50

  cluster_endpoint_public_access = true

  tags = local.tags

  depends_on = [module.vpc, module.iam]
}

# ── ECS ───────────────────────────────────────────────────────────────────────
module "ecs" {
  source = "../../modules/ecs"

  service_name = "${var.project_name}-${var.environment}-api"
  image        = "public.ecr.aws/amazonlinux/amazonlinux:latest"
  port         = 8080

  # Staging: 512 CPU / 1024 MB, desired=2, min=1, max=5
  cpu    = 512
  memory = 1024

  desired_count = 2
  min_capacity  = 1
  max_capacity  = 5

  task_execution_role_arn = module.iam.role_arns["${var.project_name}-${var.environment}-ecs-execution"]
  task_role_arn           = module.iam.role_arns["${var.project_name}-${var.environment}-ecs-task"]

  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids = module.vpc.public_subnet_ids

  env_vars = {
    ENVIRONMENT = var.environment
    DB_HOST     = module.rds.address
    DB_NAME     = module.rds.database_name
    DB_USER     = module.rds.database_user
    DB_PORT     = tostring(module.rds.port)
  }

  secret_arns = {
    DB_PASSWORD = module.secrets_manager.secret_arns["${var.project_name}/${var.environment}/db-password"]
  }

  enable_public_access = true
  health_check_path    = "/health"

  tags = local.tags

  depends_on = [module.vpc, module.iam]
}

# ── Shared DB Access Security Group ──────────────────────────────────────────
# Created outside both ECS and RDS modules to break the circular dependency:
# ECS depends on RDS (for DB_HOST), so RDS cannot depend on ECS's SG.
resource "aws_security_group" "db_access" {
  name        = "${var.project_name}-${var.environment}-db-access"
  description = "Allows access to RDS from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${var.project_name}-${var.environment}-db-access"
  })
}

# ── RDS ───────────────────────────────────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  instance_identifier = "${var.project_name}-${var.environment}"
  database_name       = "nexusdeploy"
  database_user       = "nexusdeploy"

  # Staging: db.t3.medium, single-AZ, 7-day backups, deletion protection on
  instance_class        = "db.t3.medium"
  allocated_storage     = 20
  max_allocated_storage = 100

  multi_az                = false
  backup_retention_period = 7
  deletion_protection     = true
  skip_final_snapshot     = false

  storage_encrypted = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = [aws_security_group.db_access.id]

  tags = local.tags

  depends_on = [module.vpc]
}

# ── Lambda ────────────────────────────────────────────────────────────────────
module "lambda" {
  source = "../../modules/lambda"

  function_name = "${var.project_name}-${var.environment}-event-processor"
  runtime       = "python3.12"
  handler       = "main.handler"

  s3_bucket = "${var.project_name}-${var.environment}-artifacts"
  s3_key    = "functions/event-processor.zip"

  sns_topic_name   = "${var.project_name}-${var.environment}-events"
  create_sns_topic = true

  role_arn = module.iam.role_arns["${var.project_name}-${var.environment}-lambda"]

  # Staging: 256 MB
  memory_size = 256
  timeout     = 120

  environment_variables = {
    ENVIRONMENT = var.environment
    ECS_API_URL = module.ecs.service_url
  }

  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.eks.cluster_security_group_id]
  }

  tags = local.tags

  depends_on = [module.iam, module.ecs]
}

# ── CloudWatch ────────────────────────────────────────────────────────────────
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name       = "${var.project_name}-${var.environment}"
  notification_email = "ops@nexusdeploy.example.com"

  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name
  ecs_log_group_name = "/ecs/${var.project_name}-${var.environment}-api"
  alb_arn_suffix     = module.ecs.alb_arn_suffix

  # Staging: moderate thresholds
  alert_thresholds = {
    cpu_percent    = 80
    memory_percent = 80
    error_count    = 5
  }

  health_check_targets = {}

  tags = local.tags

  depends_on = [module.ecs]
}

# ── SageMaker ─────────────────────────────────────────────────────────────────
module "sagemaker" {
  source = "../../modules/sagemaker"

  endpoint_name = "${var.project_name}-${var.environment}"
  model_name    = "${var.project_name}-${var.environment}-model"

  execution_role_arn = module.iam.role_arns["${var.project_name}-${var.environment}-sagemaker"]

  # Staging: ml.m5.large, 1-2 instances
  instance_type      = "ml.m5.large"
  min_instance_count = 1
  max_instance_count = 2

  model_image_uri = "763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.1.0-cpu-py310"
  model_data_url  = null

  create_feature_group = false

  tags = local.tags

  depends_on = [module.iam]
}

