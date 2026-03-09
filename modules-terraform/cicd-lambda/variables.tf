variable "pipeline_name" {
  type = string
}

variable "build_project_name" {
  type = string
}

variable "artifact_bucket_name" {
  type = string
}

variable "codestar_connection_arn" {
  type = string
}

variable "github_full_repository_id" {
  type = string
}

variable "github_branch" {
  type = string
}

variable "buildspec_path" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "dispatcher_lambda_function_name" {
  type    = string
  default = ""
}

variable "codepipeline_role_name" {
  type = string
}

variable "codebuild_role_name" {
  type = string
}