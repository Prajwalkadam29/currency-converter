terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # This is what your manual `eksctl create cluster --with-oidc` did -
  # without it, none of the IRSA roles (Kyverno, External Secrets) work.
  enable_irsa = true

  cluster_endpoint_public_access = true # dev/case-study convenience; restrict to a CIDR allowlist for real prod

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Project = var.project_name
  }
}