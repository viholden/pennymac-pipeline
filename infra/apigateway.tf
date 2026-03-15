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
      aws_api_gateway_method.options_movers.id,
      aws_api_gateway_integration.options_integration.id,
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

# ── CORS: OPTIONS method for preflight requests ───────────

resource "aws_api_gateway_method" "options_movers" {
  rest_api_id   = aws_api_gateway_rest_api.stock_api.id
  resource_id   = aws_api_gateway_resource.movers.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.stock_api.id
  resource_id = aws_api_gateway_resource.movers.id
  http_method = aws_api_gateway_method.options_movers.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.stock_api.id
  resource_id = aws_api_gateway_resource.movers.id
  http_method = aws_api_gateway_method.options_movers.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.stock_api.id
  resource_id = aws_api_gateway_resource.movers.id
  http_method = aws_api_gateway_method.options_movers.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
