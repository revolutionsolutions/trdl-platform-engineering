data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:revolutionsolutions@287054075/trdl-platform-engineering@1449381491:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "trdl-github-actions-deploy-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Name    = "trdl-github-actions-deploy-role"
    Project = "TRDL"
  }
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "trdl-github-actions-ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.trdl.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_eks" {
  name = "trdl-github-actions-eks"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = aws_eks_cluster.trdl.arn
      }
    ]
  })
}

# IAM policy to grants access only to the state and lock objects used by this project
resource "aws_iam_role_policy" "github_actions_terraform_state" {
  name = "trdl-github-actions-terraform-state"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::trdl-terraform-state-20261108/trdl/terraform.tfstate",
          "arn:aws:s3:::trdl-terraform-state-20261108/trdl/terraform.tfstate.tflock"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::trdl-terraform-state-20261108"
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "trdl/*"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_ec2_read" {
  name = "trdl-github-actions-ec2-read"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      }
    ]
  })
}

# These are read-only permissions for Terraform refresh and discovery

resource "aws_iam_role_policy" "github_actions_infrastructure_read" {
  name = "trdl-github-actions-infrastructure-read"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:ListTagsForResource",

          "iam:GetRole",
          "iam:GetOpenIDConnectProvider",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",

          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeAddresses",
          "ec2:DescribeAddressesAttribute",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeSecurityGroups",

          "eks:DescribeAccessEntry",
          "eks:DescribeNodegroup",
          "eks:DescribeAddon",
        ]
        Resource = "*"
      }
    ]
  })
}

