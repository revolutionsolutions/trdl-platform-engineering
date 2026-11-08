terraform {
  backend "s3" {
    bucket       = "trdl-terraform-state-20261108"
    key          = "trdl/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}