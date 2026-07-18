variable "cluster_name" { type = string }
variable "aws_region" { type = string }
variable "kyverno_role_arn" { type = string }
variable "external_secrets_role_arn" { type = string }
variable "cosign_public_key_pem" { type = string }