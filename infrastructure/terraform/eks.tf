resource "aws_eks_cluster" "trdl" {
  name     = "trdl-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.35"

  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet1.id,
      aws_subnet.private_subnet2.id
    ]

    # Access
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster
  ]

  tags = {
    Name = "trdl-eks"
  }
}

#########################################################
resource "aws_eks_node_group" "trdl" {
  cluster_name    = aws_eks_cluster.trdl.name
  node_group_name = "trdl-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    aws_subnet.private_subnet1.id,
    aws_subnet.private_subnet2.id
  ]

  instance_types = ["t2.medium"]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker,
    aws_iam_role_policy_attachment.eks_ecr,
    aws_iam_role_policy_attachment.eks_cni
  ]

  tags = {
    Name = "trdl-node-group"
  }
}

# EKS Addon
resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.trdl.name
  addon_name   = "eks-pod-identity-agent"
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.trdl.name
  addon_name   = "metrics-server"
  depends_on   = [aws_eks_node_group.trdl]
}

# bootstrap_self_managed_addons - Install default unmanaged add-ons, such as aws-cni, kube-proxy, and CoreDNS during cluster creation
/* resource "aws_eks_addon" "cordns" {
  cluster_name  = aws_eks_cluster.trdl.name
  addon_name    = "coredns"
  depends_on = [ aws_eks_node_group.trdl ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.trdl.name
  addon_name    = "kube-proxy"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.trdl.name
  addon_name    = "vpc-cni"
} */