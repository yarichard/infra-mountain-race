terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}

// Reference for terraform state outputs
terraform {
  backend "s3" {
    bucket  = "terraform-state-bucket-yrichard"
    key     = "states/mountain-race.tfstate"
    region  = "eu-west-3"
    encrypt = true
  }
}