variable "topic_name" {
  type = string
}

variable "email_subscribers" {
  type    = list(string)
  default = []
}