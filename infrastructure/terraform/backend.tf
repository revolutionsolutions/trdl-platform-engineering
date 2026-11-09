# S3 remote state configuration
terraform {
  backend "s3" {
    bucket       = "trdl-terraform-state-2026110902"
    key          = "trdl/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}