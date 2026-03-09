variable "secret_name" {
  type = string
}

variable "password_length" {
  type    = number
  default = 16
}

variable "recovery_window_in_days" {
  type    = number
  default = 0
}
