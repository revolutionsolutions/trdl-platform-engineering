output "ecr_repository_url" {
  description = "TRDL Amazon ECR repository URL"
  value       = aws_ecr_repository.trdl.repository_url
}

output "vpc_id" {
  description = "TRDL VPC ID"
  value       = aws_vpc.trdl.id
}

output "eks_cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  value       = aws_iam_role.eks_node.arn
}