###############################################################################
# AWS Production environment – multi-AZ, ON_DEMAND nodes, HA RDS,
# deletion protection, tight alert thresholds.
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
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  region   = var.region
  vpc_name = "${local.name_prefix}-vpc"
  vpc_cidr = "10.0.0.0/16"

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  availability_zones   = ["${var.region}a", "${var.region}b", "${var.region}c"]

  # Prod: one NAT gateway per AZ for HA egress
  enable_nat_gateway = true
  single_nat_gateway = false

  tags = local.common_tags
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  roles = {
    "${local.name_prefix}-eks-cluster" = {
      description = "IAM role for the EKS cluster control plane"
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
      create_instance_profile = false
    }

    "${local.name_prefix}-eks-nodes" = {
      description = "IAM role for EKS managed node groups"
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

    "${local.name_prefix}-ecs-task-execution" = {
      description = "ECS task execution role for pulling images and writing logs"
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
      create_instance_profile = false
    }

    "${local.name_prefix}-ecs-task" = {
      description = "ECS task role assumed by the running container"
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
      create_instance_profile = false
    }

    "${local.name_prefix}-lambda" = {
      description = "Execution role for Lambda functions"
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
        "arn:aws:iam::aws:policy/AmazonSNSFullAccess",
      ]
      create_instance_profile = false
    }

    "${local.name_prefix}-sagemaker" = {
      description = "Execution role for SageMaker endpoints and feature store"
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
      create_instance_profile = false
    }
  }

  tags = local.common_tags
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
module "secrets_manager" {
  source = "../../modules/secrets-manager"

  secrets = {
    db-password   = { description = "RDS master user password" }
    api-key       = { description = "External API key" }
    slack-webhook = { description = "Slack webhook URL for alerts" }
  }

  # Prod: 30-day recovery window
  recovery_window_in_days = 30

  tags = local.common_tags
}

# ── EKS ───────────────────────────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "${local.name_prefix}-eks"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  cluster_role_arn = module.iam.role_arns["${local.name_prefix}-eks-cluster"]
  node_role_arn    = module.iam.role_arns["${local.name_prefix}-eks-nodes"]

  # Prod: ON_DEMAND, larger instances, 3-10 nodes
  capacity_type       = "ON_DEMAND"
  node_instance_types = ["t3.xlarge"]
  node_desired_size   = 3
  node_min_size       = 3
  node_max_size       = 10
  node_disk_size      = 100

  cluster_endpoint_public_access = true

  tags = local.common_tags

  depends_on = [module.vpc, module.iam]
}

# ── Shared DB Access Security Group ──────────────────────────────────────────
# Created outside both ECS and RDS modules to break the circular dependency:
# ECS depends on RDS (for DB_HOST), so RDS cannot depend on ECS's SG.
resource "aws_security_group" "db_access" {
  name        = "${local.name_prefix}-db-access"
  description = "Allows access to RDS from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-access"
  })
}

# ── ECS ───────────────────────────────────────────────────────────────────────
module "ecs" {
  source = "../../modules/ecs"

  service_name = "${local.name_prefix}-api"
  image        = "public.ecr.aws/nginx/nginx:stable"
  port         = 8080

  # Prod: larger task size, 3 desired, 2-10 scaling range
  cpu    = 1024
  memory = 2048

  desired_count = 3
  min_capacity  = 2
  max_capacity  = 10

  task_execution_role_arn = module.iam.role_arns["${local.name_prefix}-ecs-task-execution"]
  task_role_arn           = module.iam.role_arns["${local.name_prefix}-ecs-task"]

  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids = module.vpc.public_subnet_ids

  env_vars = {
    ENVIRONMENT = "prod"
    DB_HOST     = module.rds.address
    DB_NAME     = module.rds.database_name
    DB_USER     = module.rds.database_user
    DB_PORT     = tostring(module.rds.port)
  }

  secret_arns = {
    DB_PASSWORD = module.secrets_manager.secret_arns["db-password"]
  }

  health_check_path    = "/health"
  enable_public_access = true

  tags = local.common_tags

  depends_on = [module.vpc, module.iam, module.rds]
}

# ── RDS ───────────────────────────────────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  instance_identifier = "${local.name_prefix}-postgres"
  database_name       = "nexusdeploy"
  database_user       = "nexusdeploy"

  # Prod: larger instance class, multi-AZ, extended backup retention
  instance_class          = "db.r6g.large"
  allocated_storage       = 50
  max_allocated_storage   = 200
  multi_az                = true
  backup_retention_period = 14
  deletion_protection     = true
  skip_final_snapshot     = false
  storage_encrypted       = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = [aws_security_group.db_access.id]

  tags = local.common_tags

  depends_on = [module.vpc]
}

# ── Lambda ────────────────────────────────────────────────────────────────────
module "lambda" {
  source = "../../modules/lambda"

  function_name = "${local.name_prefix}-event-processor"
  runtime       = "python3.12"
  handler       = "main.handler"

  s3_bucket = "${local.name_prefix}-artifacts"
  s3_key    = "functions/event-processor.zip"

  sns_topic_name   = "${local.name_prefix}-events"
  create_sns_topic = true

  role_arn = module.iam.role_arns["${local.name_prefix}-lambda"]

  # Prod: more memory, longer timeout
  memory_size = 512
  timeout     = 120

  environment_variables = {
    ENVIRONMENT = "prod"
    SERVICE_URL = module.ecs.service_url
  }

  tags = local.common_tags

  depends_on = [module.iam, module.ecs]
}

# ── CloudWatch ────────────────────────────────────────────────────────────────
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name = local.name_prefix

  notification_email = "ops@nexusdeploy.example.com"

  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name
  ecs_log_group_name = "/ecs/${local.name_prefix}-api"
  alb_arn_suffix     = module.ecs.alb_arn_suffix

  health_check_targets = {
    api = {
      fqdn = module.ecs.alb_dns_name
      port = 80
      type = "HTTP"
      path = "/health"
    }
  }

  # Prod: tight thresholds
  alert_thresholds = {
    cpu_percent    = 70
    memory_percent = 70
    error_count    = 3
  }

  tags = local.common_tags

  depends_on = [module.ecs]
}

# ── SageMaker ─────────────────────────────────────────────────────────────────
module "sagemaker" {
  source = "../../modules/sagemaker"

  endpoint_name = "${local.name_prefix}-endpoint"
  model_name    = "${local.name_prefix}-model"

  execution_role_arn = module.iam.role_arns["${local.name_prefix}-sagemaker"]

  model_image_uri = "763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.0.0-cpu-py310"
  model_data_url  = null

  # Prod: larger instances, 2-5 replicas, feature group enabled
  instance_type      = "ml.m5.xlarge"
  min_instance_count = 2
  max_instance_count = 5

  create_feature_group = true
  feature_group_name   = "${local.name_prefix}-features"

  tags = local.common_tags

  depends_on = [module.iam]
}
