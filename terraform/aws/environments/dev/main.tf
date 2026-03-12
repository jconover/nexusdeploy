###############################################################################
# Dev environment – composes all NexusDeploy AWS modules
# Sizing: spot nodes, single NAT GW, single-AZ RDS, scale-to-zero, min replicas = 0
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

  backend "s3" {} # configured via backend.hcl at init time
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "nexusdeploy"
      ManagedBy   = "terraform"
    }
  }
}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  region               = var.region
  vpc_name             = "${var.project_name}-${var.environment}"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  # Dev: single NAT GW to reduce cost
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  roles = {
    "eks-cluster" = {
      description = "EKS cluster role"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = { Service = "eks.amazonaws.com" }
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
      ]
      create_instance_profile = false
    }
    "eks-nodes" = {
      description = "EKS node group role"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = { Service = "ec2.amazonaws.com" }
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
      ]
      create_instance_profile = false
    }
    "ecs-task-execution" = {
      description = "ECS task execution role"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = { Service = "ecs-tasks.amazonaws.com" }
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
      ]
      create_instance_profile = false
    }
    "ecs-task" = {
      description = "ECS task application role"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = { Service = "ecs-tasks.amazonaws.com" }
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
      ]
      create_instance_profile = false
    }
    "lambda-execution" = {
      description = "Lambda execution role"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = { Service = "lambda.amazonaws.com" }
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
      ]
      create_instance_profile = false
    }
    "sagemaker-execution" = {
      description = "SageMaker execution role"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = { Service = "sagemaker.amazonaws.com" }
        }]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
      ]
      create_instance_profile = false
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
module "secrets_manager" {
  source = "../../modules/secrets-manager"

  secrets = {
    "db-password"   = { description = "Database password" }
    "api-key"       = { description = "API key" }
    "slack-webhook" = { description = "Slack webhook URL" }
  }

  # Dev: immediate deletion, no recovery window
  recovery_window_in_days = 0

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── EKS ───────────────────────────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  cluster_role_arn = module.iam.role_arns["eks-cluster"]
  node_role_arn    = module.iam.role_arns["eks-nodes"]

  # Dev: spot instances, minimal nodes
  capacity_type       = "SPOT"
  node_instance_types = ["t3.medium"]
  node_desired_size   = 1
  node_min_size       = 1
  node_max_size       = 3
  node_disk_size      = 50

  cluster_endpoint_public_access = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [module.vpc, module.iam]
}

# ── Shared DB Access Security Group ──────────────────────────────────────────
# Created outside both ECS and RDS modules to break the circular dependency:
# ECS depends on RDS (for DB_HOST), so RDS cannot depend on ECS's SG.
resource "aws_security_group" "db_access" {
  name        = "${var.project_name}-${var.environment}-db-access"
  description = "Allows access to RDS from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-access"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ── RDS ───────────────────────────────────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  instance_identifier = "${var.project_name}-${var.environment}-db"
  database_name       = "nexusdeploy"
  database_user       = "nexusdeploy"

  # Dev: smallest instance, single-AZ, no backups, no deletion protection
  instance_class          = "db.t3.micro"
  multi_az                = false
  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true
  storage_encrypted       = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = [aws_security_group.db_access.id]

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [module.vpc]
}

# ── ECS ───────────────────────────────────────────────────────────────────────
module "ecs" {
  source = "../../modules/ecs"

  service_name = "${var.project_name}-api-${var.environment}"
  image        = var.ecs_image

  # Dev: minimal resources, scale to zero
  cpu           = 256
  memory        = 512
  desired_count = 1
  min_capacity  = 0
  max_capacity  = 3

  task_execution_role_arn = module.iam.role_arns["ecs-task-execution"]
  task_role_arn           = module.iam.role_arns["ecs-task"]

  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids = module.vpc.public_subnet_ids

  enable_public_access = true

  env_vars = {
    DB_HOST     = module.rds.address
    DB_NAME     = module.rds.database_name
    DB_USER     = module.rds.database_user
    DB_PORT     = tostring(module.rds.port)
    ENVIRONMENT = "dev"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [module.vpc, module.iam, module.rds]
}

# ── Lambda ────────────────────────────────────────────────────────────────────
module "lambda" {
  source = "../../modules/lambda"

  function_name = "${var.project_name}-${var.environment}-event-processor"
  runtime       = "python3.12"
  handler       = "main.handler"

  s3_bucket = var.lambda_source_bucket
  s3_key    = "functions/event-processor.zip"

  sns_topic_name   = "${var.project_name}-${var.environment}-events"
  create_sns_topic = true

  role_arn = module.iam.role_arns["lambda-execution"]

  # Dev: minimal resources
  memory_size = 128
  timeout     = 60

  environment_variables = {
    API_SERVICE_URL = module.ecs.service_url
    ENVIRONMENT     = "dev"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [module.iam, module.ecs]
}

# ── SageMaker ─────────────────────────────────────────────────────────────────
module "sagemaker" {
  source = "../../modules/sagemaker"

  endpoint_name   = "${var.project_name}-${var.environment}"
  model_name      = "${var.project_name}-dev-model"
  model_image_uri = var.sagemaker_image_uri

  execution_role_arn = module.iam.role_arns["sagemaker-execution"]

  # Dev: smallest instance, single replica, no feature group
  instance_type        = "ml.t2.medium"
  min_instance_count   = 1
  max_instance_count   = 1
  create_feature_group = false

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [module.iam]
}

# ── CloudWatch ────────────────────────────────────────────────────────────────
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name       = var.project_name
  notification_email = var.alert_email

  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name
  ecs_log_group_name = "/ecs/${var.project_name}-api-${var.environment}"
  alb_arn_suffix     = module.ecs.alb_arn_suffix

  # Dev: relaxed thresholds
  alert_thresholds = {
    cpu_percent    = 90
    memory_percent = 90
    error_count    = 10
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [module.ecs]
}
