resource "aws_eks_access_entry" "github_actions" {
  cluster_name      = aws_eks_cluster.trdl.name
  principal_arn     = aws_iam_role.github_actions.arn
  type              = "STANDARD"
  kubernetes_groups = ["trdl-deployer"]

  tags = {
    Name      = "trdl-github-actions-access"
    Project   = "TRDL"
    ManagedBy = "Terraform"
  }
}