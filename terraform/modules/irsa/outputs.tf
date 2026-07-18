output "kyverno_role_arn" { value = aws_iam_role.kyverno_ecr_read.arn }
output "external_secrets_role_arn" { value = aws_iam_role.external_secrets.arn }