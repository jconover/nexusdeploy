output "endpoint_arn" {
  description = "The ARN of the SageMaker endpoint"
  value       = aws_sagemaker_endpoint.main.arn
}

output "endpoint_name" {
  description = "The name of the SageMaker endpoint"
  value       = aws_sagemaker_endpoint.main.name
}

output "endpoint_config_name" {
  description = "The name of the SageMaker endpoint configuration"
  value       = aws_sagemaker_endpoint_configuration.main.name
}

output "model_name" {
  description = "The name of the SageMaker model"
  value       = aws_sagemaker_model.main.name
}

output "feature_group_name" {
  description = "The name of the SageMaker Feature Store feature group (empty string if not created)"
  value       = var.create_feature_group ? aws_sagemaker_feature_group.main[0].feature_group_name : ""
}
