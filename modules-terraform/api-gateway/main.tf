resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt-authorizer"

  jwt_configuration {
    audience = [var.cognito_user_pool_client_id]
    issuer   = "https://cognito-idp.${var.cognito_user_pool_region}.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

resource "aws_apigatewayv2_integration" "greeter" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.greeter_lambda_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "dispatcher" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.dispatcher_lambda_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "greet" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /greet"
  target    = "integrations/${aws_apigatewayv2_integration.greeter.id}"

  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "dispatch" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /dispatch"
  target    = "integrations/${aws_apigatewayv2_integration.dispatcher.id}"

  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }

}

resource "aws_wafv2_web_acl_association" "api" {
  count = var.enable_waf && var.waf_web_acl_arn != "" ? 1 : 0

  resource_arn = aws_apigatewayv2_stage.default.arn
  web_acl_arn  = var.waf_web_acl_arn
}

resource "aws_lambda_permission" "allow_greet" {
  statement_id  = "AllowExecutionFromAPIGatewayGreet"
  action        = "lambda:InvokeFunction"
  function_name = var.greeter_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/greet"
}

resource "aws_lambda_permission" "allow_dispatch" {
  statement_id  = "AllowExecutionFromAPIGatewayDispatch"
  action        = "lambda:InvokeFunction"
  function_name = var.dispatcher_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/dispatch"
}