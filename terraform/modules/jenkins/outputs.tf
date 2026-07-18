output "instance_id" { value = aws_instance.jenkins.id }
output "public_ip" { value = aws_instance.jenkins.public_ip }
output "iam_role_arn" { value = aws_iam_role.jenkins_ecr_push.arn }
output "security_group_id" { value = aws_security_group.jenkins.id }