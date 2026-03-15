# ── EventBridge rule — runs daily at 9pm UTC (after US market close) ──

resource "aws_cloudwatch_event_rule" "daily_stock_trigger" {
  name                = "${var.project_name}-daily-trigger"
  description         = "Triggers ingestor Lambda daily after market close"
  schedule_expression = "cron(0 21 * * ? *)"  # 9pm UTC = ~5pm ET, after 4pm market close

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── Wire the rule to the ingestor Lambda ─────────────────

resource "aws_cloudwatch_event_target" "ingestor_target" {
  rule      = aws_cloudwatch_event_rule.daily_stock_trigger.name
  target_id = "IngestorLambdaTarget"
  arn       = aws_lambda_function.ingestor.arn
}

# ── Give EventBridge permission to invoke the Lambda ─────

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_stock_trigger.arn
}
