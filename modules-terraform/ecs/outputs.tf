output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}

output "task_security_group_id" {
  value = aws_security_group.task.id
}

output "public_subnet_ids" {
  value = var.public_subnet_ids
}

output "public_subnet_ids_csv" {
  value = join(",", var.public_subnet_ids)
}