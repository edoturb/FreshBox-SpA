# ============================================================
# EP3 — Componentes Serverless (DynamoDB, SQS, Lambdas, API Gateway, S3 frontend)
# Reutiliza: aws_vpc.freshbox_vpc, aws_subnet.private_app_1a/1b,
# aws_security_group.app, aws_db_instance.freshbox_rds, aws_route_table.private
# (definidos en main.tf / security_groups.tf / rds.tf)
# ============================================================

locals {
  lambda_subnet_ids = [aws_subnet.private_app_1a.id, aws_subnet.private_app_1b.id]
  lambda_sg_ids     = [aws_security_group.app.id]
}

# ---------- DynamoDB: carrito de compras ----------
resource "aws_dynamodb_table" "carrito" {
  name         = "carrito-freshbox"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "productId"

  attribute {
    name = "userId"
    type = "S"
  }
  attribute {
    name = "productId"
    type = "S"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = { Name = "carrito-freshbox" }
}

# ---------- VPC Endpoint Gateway: acceso privado a DynamoDB ----------
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.freshbox_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "freshbox-dynamodb-endpoint" }
}

# ---------- SQS: cola de órdenes + DLQ ----------
resource "aws_sqs_queue" "ordenes_dlq" {
  name = "ordenes-freshbox-dlq"
  tags = { Name = "ordenes-freshbox-dlq" }
}

resource "aws_sqs_queue" "ordenes" {
  name                       = "ordenes-freshbox"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ordenes_dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "ordenes-freshbox" }
}

# ---------- Empaquetado de las 3 Lambdas ----------
data "archive_file" "procesar_carrito" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/procesar-carrito"
  output_path = "${path.module}/build/procesar-carrito.zip"
}

data "archive_file" "crear_orden" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/crear-orden"
  output_path = "${path.module}/build/crear-orden.zip"
}

data "archive_file" "procesar_orden" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/procesar-orden"
  output_path = "${path.module}/build/procesar-orden.zip"
}

# ---------- Lambda: Cart (carrito) ----------
resource "aws_lambda_function" "procesar_carrito" {
  function_name    = "freshbox-procesar-carrito"
  filename         = data.archive_file.procesar_carrito.output_path
  source_code_hash = data.archive_file.procesar_carrito.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = local.lab_role_arn
  timeout          = 10
  memory_size      = 256

  vpc_config {
    subnet_ids         = local.lambda_subnet_ids
    security_group_ids = local.lambda_sg_ids
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.carrito.name
    }
  }

  depends_on = [aws_vpc_endpoint.dynamodb]
}

# ---------- Lambda: Create-Order ----------
resource "aws_lambda_function" "crear_orden" {
  function_name    = "freshbox-crear-orden"
  filename         = data.archive_file.crear_orden.output_path
  source_code_hash = data.archive_file.crear_orden.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = local.lab_role_arn
  timeout          = 10
  memory_size      = 256

  vpc_config {
    subnet_ids         = local.lambda_subnet_ids
    security_group_ids = local.lambda_sg_ids
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.carrito.name
      QUEUE_URL  = aws_sqs_queue.ordenes.url
    }
  }

  depends_on = [aws_vpc_endpoint.dynamodb]
}

# ---------- Lambda: Process-Order (trigger SQS, escribe en RDS) ----------
resource "aws_lambda_function" "procesar_orden" {
  function_name    = "freshbox-procesar-orden"
  filename         = data.archive_file.procesar_orden.output_path
  source_code_hash = data.archive_file.procesar_orden.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = local.lab_role_arn
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = local.lambda_subnet_ids
    security_group_ids = local.lambda_sg_ids
  }

  environment {
    variables = {
      DB_HOST    = aws_db_instance.freshbox_rds.address
      DB_USER    = var.db_user
      DB_PASS    = var.db_password
      DB_NAME    = var.db_name
      DB_PORT    = "3306"
      TABLE_NAME = aws_dynamodb_table.carrito.name
    }
  }

  depends_on = [aws_vpc_endpoint.dynamodb]
}

# RDS (freshbox-data-sg) debe aceptar conexiones desde el SG de las Lambdas.
# Como las Lambdas usan freshbox-app-sg (igual que EKS), la regla ya existente
# en security_groups.tf (ingress 3306 desde aws_security_group.app) cubre este caso.

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.ordenes.arn
  function_name    = aws_lambda_function.procesar_orden.arn
  batch_size       = 5
}

# ---------- API Gateway (REST) ----------
resource "aws_api_gateway_rest_api" "freshbox_api" {
  name = "freshbox-api"
}

resource "aws_api_gateway_resource" "cart" {
  rest_api_id = aws_api_gateway_rest_api.freshbox_api.id
  parent_id   = aws_api_gateway_rest_api.freshbox_api.root_resource_id
  path_part   = "cart"
}

resource "aws_api_gateway_resource" "cart_item" {
  rest_api_id = aws_api_gateway_rest_api.freshbox_api.id
  parent_id   = aws_api_gateway_resource.cart.id
  path_part   = "{productId}"
}

resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.freshbox_api.id
  parent_id   = aws_api_gateway_rest_api.freshbox_api.root_resource_id
  path_part   = "orders"
}

# --- /cart GET ---
resource "aws_api_gateway_method" "cart_get" {
  rest_api_id   = aws_api_gateway_rest_api.freshbox_api.id
  resource_id   = aws_api_gateway_resource.cart.id
  http_method   = "GET"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "cart_get" {
  rest_api_id             = aws_api_gateway_rest_api.freshbox_api.id
  resource_id              = aws_api_gateway_resource.cart.id
  http_method              = aws_api_gateway_method.cart_get.http_method
  integration_http_method = "POST"
  type                     = "AWS_PROXY"
  uri                      = aws_lambda_function.procesar_carrito.invoke_arn
}

# --- /cart POST ---
resource "aws_api_gateway_method" "cart_post" {
  rest_api_id   = aws_api_gateway_rest_api.freshbox_api.id
  resource_id   = aws_api_gateway_resource.cart.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "cart_post" {
  rest_api_id              = aws_api_gateway_rest_api.freshbox_api.id
  resource_id              = aws_api_gateway_resource.cart.id
  http_method              = aws_api_gateway_method.cart_post.http_method
  integration_http_method = "POST"
  type                     = "AWS_PROXY"
  uri                      = aws_lambda_function.procesar_carrito.invoke_arn
}

# --- /cart/{productId} DELETE ---
resource "aws_api_gateway_method" "cart_delete" {
  rest_api_id   = aws_api_gateway_rest_api.freshbox_api.id
  resource_id   = aws_api_gateway_resource.cart_item.id
  http_method   = "DELETE"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "cart_delete" {
  rest_api_id              = aws_api_gateway_rest_api.freshbox_api.id
  resource_id              = aws_api_gateway_resource.cart_item.id
  http_method              = aws_api_gateway_method.cart_delete.http_method
  integration_http_method = "POST"
  type                     = "AWS_PROXY"
  uri                      = aws_lambda_function.procesar_carrito.invoke_arn
}

# --- /orders POST ---
resource "aws_api_gateway_method" "orders_post" {
  rest_api_id   = aws_api_gateway_rest_api.freshbox_api.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "orders_post" {
  rest_api_id              = aws_api_gateway_rest_api.freshbox_api.id
  resource_id              = aws_api_gateway_resource.orders.id
  http_method              = aws_api_gateway_method.orders_post.http_method
  integration_http_method = "POST"
  type                     = "AWS_PROXY"
  uri                      = aws_lambda_function.crear_orden.invoke_arn
}

resource "aws_lambda_permission" "apigw_carrito" {
  statement_id  = "apigw-invoke-carrito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.procesar_carrito.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.freshbox_api.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "apigw_orden" {
  statement_id  = "apigw-invoke-orden"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crear_orden.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.freshbox_api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.freshbox_api.id

  depends_on = [
    aws_api_gateway_integration.cart_get,
    aws_api_gateway_integration.cart_post,
    aws_api_gateway_integration.cart_delete,
    aws_api_gateway_integration.orders_post,
  ]

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.cart.id,
      aws_api_gateway_resource.cart_item.id,
      aws_api_gateway_resource.orders.id,
      aws_api_gateway_integration.cart_get.id,
      aws_api_gateway_integration.cart_post.id,
      aws_api_gateway_integration.cart_delete.id,
      aws_api_gateway_integration.orders_post.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.freshbox_api.id
  deployment_id = aws_api_gateway_deployment.prod.id
  stage_name    = "prod"
}

# ---------- Frontend estático en S3 ----------
# El bucket ya existe (creado manualmente durante el despliegue inicial).
# AWS Academy bloquea s3:GetBucketObjectLockConfiguration via SCP, lo que
# impide que Terraform gestione aws_s3_bucket como resource completo.
# Se referencia como data source (solo lectura) en su lugar.
data "aws_s3_bucket" "frontend" {
  bucket = "freshbox-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = data.aws_s3_bucket.frontend.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = data.aws_s3_bucket.frontend.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = data.aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${data.aws_s3_bucket.frontend.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

locals {
  content_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    svg  = "image/svg+xml"
  }
}

resource "aws_s3_object" "frontend_files" {
  for_each     = fileset("${path.module}/../S3Frontend", "**")
  bucket       = data.aws_s3_bucket.frontend.id
  key          = each.value
  source       = "${path.module}/../S3Frontend/${each.value}"
  etag         = filemd5("${path.module}/../S3Frontend/${each.value}")
  content_type = lookup(local.content_types, reverse(split(".", each.value))[0], "application/octet-stream")
}

# El frontend referencia API_URL_EKS (ALB, lo crea el AWS Load Balancer
# Controller fuera de Terraform) y API_URL_SERVERLESS (este API Gateway).
# Tras el primer apply, actualiza manualmente S3Frontend/js/app.js con
# ambas URLs reales y corre `terraform apply` de nuevo para re-subirlo
# (ver outputs api_gateway_url / alb_hint más abajo).
