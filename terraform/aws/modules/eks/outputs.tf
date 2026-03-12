output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_id" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster, used for IRSA configuration"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the EKS cluster, used in IRSA trust policies"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "cluster_security_group_id" {
  description = "ID of the additional security group attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "node_group_id" {
  description = "ID of the EKS managed node group"
  value       = aws_eks_node_group.main.id
}
