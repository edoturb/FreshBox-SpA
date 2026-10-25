terraform {
  backend "s3" {
    bucket = "freshbox-tfstate-850411985525"
    key    = "ep1/terraform.tfstate"
    region = "us-east-1"
  }
}
