resource "aws_sns_topic" "main" {
  count = var.create_sns_topic ? 1 : 0

  name = var.sns_topic_name
  tags = var.tags
}

data "aws_sns_topic" "existing" {
  count = var.create_sns_topic ? 0 : 1

  name = var.sns_topic_name
}

locals {
  sns_topic_arn = var.create_sns_topic ? aws_sns_topic.main[0].arn : data.aws_sns_topic.existing[0].arn
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "main" {
  function_name = var.function_name
  runtime       = var.runtime
  handler       = var.handler
  role          = var.role_arn
  s3_bucket     = var.s3_bucket
  s3_key        = var.s3_key

  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions

  environment {
    variables = var.environment_variables
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.main]
}

resource "aws_sns_topic_subscription" "main" {
  topic_arn = local.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.main.arn
}

resource "aws_lambda_permission" "sns" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = local.sns_topic_arn
}
