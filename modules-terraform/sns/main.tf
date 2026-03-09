resource "aws_sns_topic" "this" {
  name = var.topic_name
  tags = { Name = var.topic_name }
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.email_subscribers)

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}