variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "oidc_provider_arn" { type = string }
variable "cluster_oidc_issuer_url" { type = string }
variable "ecr_repository_arn" { type = string }
variable "environments" { type = list(string) }