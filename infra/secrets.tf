resource "aws_secretsmanager_secret" "massive_api_key" {
  name        = "${var.project_name}/massive-api-key"
  description = "Polygon.io API key for stock data fetching"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "massive_api_key_value" {
  secret_id     = aws_secretsmanager_secret.massive_api_key.id
  secret_string = var.massive_api_key
}
