terraform {
  backend "s3" {
    bucket = "freshbox-tfstate-730335319943"
    key    = "ep1/terraform.tfstate"
    region = "us-east-1"
  }
}
