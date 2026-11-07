
resource "aws_ecr_repository" "trdl" {
  name                 = "trdl"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "trdl-ecr"
  }
}