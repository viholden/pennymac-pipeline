# ── Package Lambda code into zip files ───────────────────

data "archive_file" "ingestor_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/ingestor/handler.py"
  output_path = "${path.module}/../lambdas/ingestor/handler.zip"
}

data "archive_file" "retriever_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/retriever/handler.py"
  output_path = "${path.module}/../lambdas/retriever/handler.zip"
}


# ── IAM role that both Lambdas assume ─────────────────────

resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Basic Lambda logging — allows writing to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic_logging" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# ── Ingestor-specific permissions (write to DynamoDB + read secret) ──

resource "aws_iam_role_policy" "ingestor_policy" {
  name = "${var.project_name}-ingestor-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Can only write to THIS specific table — not all DynamoDB tables
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.stock_movers.arn
      },
      {
        # Can only read THIS specific secret — not all secrets
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.massive_api_key.arn
      }
    ]
  })
}


# ── Retriever-specific permissions (read from DynamoDB only) ─────────

resource "aws_iam_role_policy" "retriever_policy" {
  name = "${var.project_name}-retriever-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Can only read from THIS specific table — cannot write
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = aws_dynamodb_table.stock_movers.arn
      }
    ]
  })
}


# ── Ingestor Lambda function ──────────────────────────────

resource "aws_lambda_function" "ingestor" {
  function_name    = "${var.project_name}-ingestor"
  filename         = data.archive_file.ingestor_zip.output_path
  source_code_hash = data.archive_file.ingestor_zip.output_base64sha256
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 30   # 30s — enough for 6 API calls with retries

  environment {
    variables = {
      DYNAMODB_TABLE  = aws_dynamodb_table.stock_movers.name
      SECRET_NAME     = aws_secretsmanager_secret.massive_api_key.name
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ── Retriever Lambda function ─────────────────────────────

resource "aws_lambda_function" "retriever" {
  function_name    = "${var.project_name}-retriever"
  filename         = data.archive_file.retriever_zip.output_path
  source_code_hash = data.archive_file.retriever_zip.output_base64sha256
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "handler.handler"
  runtime          = "python3.11"
  timeout          = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.stock_movers.name
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ── CloudWatch Log Groups ─────────────────────────────────
# Explicitly create these so Terraform manages them (they'd
# auto-create anyway but this lets you control retention)

resource "aws_cloudwatch_log_group" "ingestor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ingestor.function_name}"
  retention_in_days = 7

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "retriever_logs" {
  name              = "/aws/lambda/${aws_lambda_function.retriever.function_name}"
  retention_in_days = 7

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
