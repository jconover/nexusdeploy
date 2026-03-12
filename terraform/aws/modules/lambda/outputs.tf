output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function (for use with API Gateway)"
  value       = aws_lambda_function.main.invoke_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic (created or existing)"
  value       = local.sns_topic_arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = var.sns_topic_name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for the Lambda function"
  value       = aws_cloudwatch_log_group.main.name
}
