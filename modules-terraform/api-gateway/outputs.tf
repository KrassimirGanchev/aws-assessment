output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}

output "greet_url" {
  value = "${aws_apigatewayv2_api.this.api_endpoint}/greet"
}

output "dispatch_url" {
  value = "${aws_apigatewayv2_api.this.api_endpoint}/dispatch"
}