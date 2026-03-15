resource "aws_dynamodb_table" "stock_movers" {
  name         = "${var.project_name}-table"
  billing_mode = "PAY_PER_REQUEST"  # on-demand, no capacity planning needed
  hash_key     = "date"             # partition key — one record per day

  attribute {
    name = "date"
    type = "S"  # String, format: "YYYY-MM-DD"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
