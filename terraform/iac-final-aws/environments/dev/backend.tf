# IMPORTANTE: reemplaza el bucket y la tabla por los que crees en el Paso 2
# de las instrucciones (deben existir ANTES de correr `terraform init`).
terraform {
  backend "s3" {
    bucket         = "TU-NOMBRE-tfstate-iac-final"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
