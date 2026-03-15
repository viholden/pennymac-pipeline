output "api_endpoint" {
  description = "The live URL for GET /movers"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/movers"
}

output "frontend_url" {
  description = "The public S3 website URL"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.stock_movers.name
}

output "ingestor_function_name" {
  description = "Ingestor Lambda name — use this to manually trigger a test run"
  value       = aws_lambda_function.ingestor.function_name
}
