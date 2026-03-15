variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used to name all resources consistently"
  type        = string
  default     = "stock-movers"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "massive_api_key" {
  description = "API key for Polygon.io stock data — passed in via env, never hardcoded"
  type        = string
  sensitive   = true
}
