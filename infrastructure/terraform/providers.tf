# AWS provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TRDL"
      Environment = "assessment"
      ManagedBy   = "Terraform"
    }
  }
}
