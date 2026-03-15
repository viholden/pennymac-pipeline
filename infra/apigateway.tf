# ── REST API ──────────────────────────────────────────────

resource "aws_api_gateway_rest_api" "stock_api" {
  name        = "${var.project_name}-api"
  description = "REST API for stock movers dashboard"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── /movers resource ──────────────────────────────────────

resource "aws_api_gateway_resource" "movers" {
  rest_api_id = aws_api_gateway_rest_api.stock_api.id
  parent_id   = aws_api_gateway_rest_api.stock_api.root_resource_id
  path_part   = "movers"
}

# ── GET method ────────────────────────────────────────────

resource "aws_api_gateway_method" "get_movers" {
  rest_api_id   = aws_api_gateway_rest_api.stock_api.id
  resource_id   = aws_api_gateway_resource.movers.id
  http_method   = "GET"
  authorization = "NONE"
}

# ── Wire GET /movers to the retriever Lambda ──────────────

resource "aws_api_gateway_integration" "get_movers_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stock_api.id
  resource_id             = aws_api_gateway_resource.movers.id
  http_method             = aws_api_gateway_method.get_movers.http_method
  integration_http_method = "POST"  # API Gateway always uses POST to invoke Lambda
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.retriever.invoke_arn
}

# ── Deploy the API ────────────────────────────────────────

resource "aws_api_gateway_deployment" "stock_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.stock_api.id

  # Force a new deployment whenever the method or integration changes
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.movers.id,
      aws_api_gateway_method.get_movers.id,
      aws_api_gateway_integration.get_movers_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.stock_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.stock_api.id
  stage_name    = "prod"
}

# ── Give API Gateway permission to invoke the Lambda ─────

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retriever.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.stock_api.execution_arn}/*/*"
}
