// Reference for tfstate bucket policy
data "terraform_remote_state" "bootstrap-tfstate" {
  backend = "s3"
  config = {
    bucket = "terraform-state-bucket-yrichard"
    key    = "bootstrap/terraform.tfstate"
    region = "eu-west-3"
  }
}

