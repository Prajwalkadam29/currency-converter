module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
}

module "eks" {
  source              = "./modules/eks"
  project_name        = var.project_name
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

module "ecr" {
  source          = "./modules/ecr"
  project_name    = var.project_name
  repository_name = var.ecr_repository_name
}

module "irsa" {
  source                  = "./modules/irsa"
  project_name            = var.project_name
  aws_region              = var.aws_region
  oidc_provider_arn       = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  ecr_repository_arn      = module.ecr.repository_arn
  environments            = ["dev", "staging", "prod"]
}

module "jenkins" {
  source           = "./modules/jenkins"
  project_name     = var.project_name
  vpc_id           = module.networking.vpc_id
  public_subnet_id = module.networking.public_subnet_ids[0]
  instance_type    = var.jenkins_instance_type
  key_pair_name    = var.jenkins_key_pair_name
  allowed_ssh_cidr = var.jenkins_allowed_ssh_cidr
}


module "addons" {
  source                    = "./modules/addons"
  cluster_name              = var.cluster_name
  aws_region                = var.aws_region
  kyverno_role_arn          = module.irsa.kyverno_role_arn
  external_secrets_role_arn = module.irsa.external_secrets_role_arn
  cosign_public_key_pem     = var.cosign_public_key_pem
  depends_on                = [module.eks]
}