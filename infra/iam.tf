data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "contact_form_lambda" {
  name               = "${var.project_name}-contact-form-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.contact_form_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Scoped to only SendEmail/SendRawEmail, and only from the verified sender
# identity - this Lambda cannot send arbitrary email as anyone else.
data "aws_iam_policy_document" "lambda_ses_send" {
  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = [aws_ses_email_identity.sender.arn]
  }
}

resource "aws_iam_role_policy" "lambda_ses_send" {
  name   = "${var.project_name}-lambda-ses-send"
  role   = aws_iam_role.contact_form_lambda.id
  policy = data.aws_iam_policy_document.lambda_ses_send.json
}
