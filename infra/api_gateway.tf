# HTTP API (not REST API) - see the ADR for why. It's the cheaper, simpler
# API Gateway product type, and it natively supports CORS configuration
# without needing a hand-rolled OPTIONS method + mock integration, which
# the older REST API type requires.

resource "aws_apigatewayv2_api" "contact_form" {
  name          = "${var.project_name}-contact-form-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://${var.domain_name}"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "contact_form" {
  api_id                 = aws_apigatewayv2_api.contact_form.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.contact_form.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "contact_form" {
  api_id    = aws_apigatewayv2_api.contact_form.id
  route_key = "POST /contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact_form.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.contact_form.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip              = "$context.identity.sourceIp"
      requestTime     = "$context.requestTime"
      routeKey        = "$context.routeKey"
      status          = "$context.status"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-contact-form-api"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_form.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact_form.execution_arn}/*/*"
}
