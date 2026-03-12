resource "aws_sagemaker_model" "main" {
  name               = var.model_name
  execution_role_arn = var.execution_role_arn

  primary_container {
    image          = var.model_image_uri
    model_data_url = var.model_data_url != null ? var.model_data_url : null
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnets            = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [primary_container[0].image]
  }
}

resource "aws_sagemaker_endpoint_configuration" "main" {
  name = "${var.endpoint_name}-config"

  production_variants {
    variant_name           = "primary"
    model_name             = aws_sagemaker_model.main.name
    instance_type          = var.instance_type
    initial_instance_count = var.min_instance_count
  }

  tags = var.tags
}

resource "aws_sagemaker_endpoint" "main" {
  name                 = var.endpoint_name
  endpoint_config_name = aws_sagemaker_endpoint_configuration.main.name

  tags = var.tags
}

resource "aws_sagemaker_feature_group" "main" {
  count = var.create_feature_group ? 1 : 0

  feature_group_name             = var.feature_group_name
  record_identifier_feature_name = "record_id"
  event_time_feature_name        = "event_time"
  role_arn                       = var.execution_role_arn

  online_store_config {
    enable_online_store = true
  }

  feature_definition {
    feature_name = "record_id"
    feature_type = "String"
  }

  feature_definition {
    feature_name = "event_time"
    feature_type = "String"
  }

  tags = var.tags
}
