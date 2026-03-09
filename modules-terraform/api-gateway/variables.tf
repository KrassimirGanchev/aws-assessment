variable "api_name" {
  type = string
}

variable "greeter_lambda_function_name" {
  type = string
}

variable "greeter_lambda_invoke_arn" {
  type = string
}

variable "dispatcher_lambda_function_name" {
  type = string
}

variable "dispatcher_lambda_invoke_arn" {
  type = string
}

variable "cognito_user_pool_id" {
  type = string
}

variable "cognito_user_pool_client_id" {
  type = string
}

variable "cognito_user_pool_region" {
  type = string
}

variable "throttling_burst_limit" {
  type    = number
  default = 20
}

variable "throttling_rate_limit" {
  type    = number
  default = 10
}

variable "enable_waf" {
  type    = bool
  default = false
}

variable "waf_web_acl_arn" {
  type    = string
  default = ""
}

variable "access_log_retention_in_days" {
  type    = number
  default = 14
}