resource "random_password" "cognito_temp_password" {
  length           = var.password_length
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!@#$%^&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "this" {
  name                    = var.secret_name
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name = var.secret_name
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = random_password.cognito_temp_password.result
}
