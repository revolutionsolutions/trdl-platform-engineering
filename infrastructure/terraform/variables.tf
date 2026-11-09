variable "aws_region" {
  description = "AWS region for the TRDL infrastructure"
  type        = string
  default     = "us-east-1"
}
variable "terraform_state_bucket" {
  description = "S3 bucket used to store Terraform state"
  type        = string
  default     = "trdl-terraform-state-2026110902"
}