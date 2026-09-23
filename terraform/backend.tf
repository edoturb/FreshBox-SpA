terraform {
  backend "s3" {
    bucket = "freshbox-tfstate-722802907878"
    key    = "ep1/terraform.tfstate"
    region = "us-east-1"
  }
}
