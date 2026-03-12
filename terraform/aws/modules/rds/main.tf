resource "aws_db_subnet_group" "this" {
  name       = "${var.instance_identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.instance_identifier}-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.instance_identifier}-rds-sg"
  description = "Security group for RDS instance ${var.instance_identifier}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.instance_identifier}-rds-sg"
  })
}

resource "aws_db_instance" "this" {
  identifier        = var.instance_identifier
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  max_allocated_storage = var.max_allocated_storage

  db_name  = var.database_name
  username = var.database_user

  manage_master_user_password = true

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.instance_identifier}-final"

  performance_insights_enabled = true
  publicly_accessible          = false
  apply_immediately            = false

  tags = merge(var.tags, {
    Name = var.instance_identifier
  })
}
