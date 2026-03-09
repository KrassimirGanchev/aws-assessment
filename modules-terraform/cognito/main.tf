locals {
  use_mock_test_user_password       = can(regex(":000000000000:secret:mock-", var.test_user_temporary_password_secret_arn))
  should_lookup_test_user_password  = var.create_test_user && !local.use_mock_test_user_password
  test_user_temporary_password      = local.use_mock_test_user_password ? "MockTempPass123!" : (local.should_lookup_test_user_password ? trimspace(data.aws_secretsmanager_secret_version.test_user_password[0].secret_string) : null)
}

data "aws_secretsmanager_secret_version" "test_user_password" {
  count = local.should_lookup_test_user_password ? 1 : 0

  secret_id = var.test_user_temporary_password_secret_arn
}

resource "aws_cognito_user_pool" "this" {
  name = var.user_pool_name

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  tags = {
    Name = var.user_pool_name
  }
}

resource "aws_cognito_user_pool_client" "this" {
  name         = var.user_pool_client_name
  user_pool_id = aws_cognito_user_pool.this.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
  prevent_user_existence_errors = "ENABLED"
  generate_secret               = false
}

resource "aws_cognito_user" "test_user" {
  count = var.create_test_user ? 1 : 0

  user_pool_id = aws_cognito_user_pool.this.id
  username     = var.test_user_email

  attributes = {
    email          = var.test_user_email
    email_verified = "true"
  }

  temporary_password = local.test_user_temporary_password
  message_action     = "SUPPRESS"
}
