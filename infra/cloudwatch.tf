resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms"
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
  # Note: SNS sends a confirmation email after apply - you must click the
  # "Confirm subscription" link in it, or alarm notifications won't arrive.
  # Terraform cannot click that link on your behalf.
}

resource "aws_cloudwatch_metric_alarm" "contact_form_errors" {
  alarm_name        = "${var.project_name}-contact-form-lambda-errors"
  alarm_description = "Fires when the contact form Lambda throws errors, so a broken form doesn't fail silently."
  namespace         = "AWS/Lambda"
  metric_name       = "Errors"
  dimensions = {
    FunctionName = aws_lambda_function.contact_form.function_name
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}
