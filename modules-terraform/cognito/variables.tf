variable "user_pool_name" {
  type = string
}

variable "user_pool_client_name" {
  type = string
}

variable "test_user_email" {
  type = string
}

variable "create_test_user" {
  type    = bool
  default = true
}

variable "test_user_temporary_password_secret_arn" {
  type = string
}