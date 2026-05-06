resource "aws_ecr_repository" "mountain_race" {
  name = var.mountain_race_ecr_repo

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  force_delete = true
}
