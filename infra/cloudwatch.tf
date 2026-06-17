resource "aws_sns_topic" "alerts" {
  name = "portfolio-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.recipient_email
  # AWS emails a confirmation link to recipient_email after apply -
  # the subscription stays "PendingConfirmation" until you click it.
}

resource "aws_cloudwatch_metric_alarm" "contact_form_errors" {
  alarm_name          = "portfolio-contact-form-lambda-errors"
  alarm_description   = "Fires if the contact form Lambda throws any errors."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions = {
    FunctionName = aws_lambda_function.contact_form.function_name
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}
