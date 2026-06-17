data "archive_file" "contact_form" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/contact_form"
  output_path = "${path.module}/build/contact_form.zip"
}

resource "aws_iam_role" "contact_form" {
  name = "portfolio-contact-form-lambda"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "contact_form_ses" {
  name = "send-via-ses"
  role = aws_iam_role.contact_form.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "contact_form_logs" {
  role       = aws_iam_role.contact_form.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "contact_form" {
  name              = "/aws/lambda/portfolio-contact-form"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_lambda_function" "contact_form" {
  function_name    = "portfolio-contact-form"
  role             = aws_iam_role.contact_form.arn
  handler          = "handler.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.contact_form.output_path
  source_code_hash = data.archive_file.contact_form.output_base64sha256
  timeout          = 10
  memory_size      = 128
  tags             = var.tags

  environment {
    variables = {
      SENDER_EMAIL    = var.sender_email
      RECIPIENT_EMAIL = var.recipient_email
      ALLOWED_ORIGIN  = "https://${var.domain_name}"
    }
  }

  depends_on = [aws_cloudwatch_log_group.contact_form]
}
