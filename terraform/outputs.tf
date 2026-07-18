output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "jenkins_public_ip" {
  value = module.jenkins.public_ip
}