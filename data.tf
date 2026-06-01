data "terraform_remote_state" "bootstrap-tfstate" {
  backend = "s3"
  config = {
    bucket = "terraform-state-bucket-yrichard"
    key    = "bootstrap/terraform.tfstate"
    region = "eu-west-3"
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
