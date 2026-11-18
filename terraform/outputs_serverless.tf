output "api_gateway_url" {
  description = "URL base del API Gateway (stage prod) para carrito y órdenes"
  value       = "https://${aws_api_gateway_rest_api.freshbox_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
}

output "frontend_url" {
  description = "URL del sitio estático S3 (frontend)"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "frontend_bucket" {
  value = data.aws_s3_bucket.frontend.id
}

output "dynamodb_table" {
  value = aws_dynamodb_table.carrito.name
}

output "sqs_queue_url" {
  value = aws_sqs_queue.ordenes.url
}

output "sqs_dlq_url" {
  value = aws_sqs_queue.ordenes_dlq.url
}

output "lambda_functions" {
  value = [
    aws_lambda_function.procesar_carrito.function_name,
    aws_lambda_function.crear_orden.function_name,
    aws_lambda_function.procesar_orden.function_name,
  ]
}
