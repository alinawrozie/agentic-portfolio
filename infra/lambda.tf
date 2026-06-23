# `archive_file` zips up lambda/handler.py at apply time, so there's no
# manual "zip and upload" step - the deployed code is always exactly what's
# in the repo. source_code_hash forces a redeploy whenever handler.py
# changes, so `terraform apply` reliably picks up code edits.

data "archive_file" "contact_form" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/build/contact_form.zip"
}

resource "aws_lambda_function" "contact_form" {
  function_name    = "${var.project_name}-contact-form"
  role             = aws_iam_role.contact_form_lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.contact_form.output_path
  source_code_hash = data.archive_file.contact_form.output_base64sha256

  environment {
    variables = {
      SENDER_EMAIL    = var.ses_sender_email
      RECIPIENT_EMAIL = var.contact_form_recipient_email
      ALLOWED_ORIGIN  = "https://${var.domain_name}"
    }
  }
}

resource "aws_cloudwatch_log_group" "contact_form" {
  name              = "/aws/lambda/${aws_lambda_function.contact_form.function_name}"
  retention_in_days = 30
}
