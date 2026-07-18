terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    helm       = { source = "hashicorp/helm" }
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata { name = "argocd" }
}

resource "kubernetes_namespace" "kyverno" {
  metadata { name = "kyverno" }
}

resource "kubernetes_namespace" "external_secrets" {
  metadata { name = "external-secrets" }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.7.11"
}

resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  namespace  = kubernetes_namespace.kyverno.metadata[0].name
  version    = "3.8.2"

  set {
    name  = "admissionController.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.kyverno_role_arn
  }

  set {
    name  = "admissionController.container.extraArgs.registryCredentialHelpers"
    value = "amazon"
  }
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  version    = "0.10.4"

  set {
    name  = "serviceAccount.name"
    value = "external-secrets-sa"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.external_secrets_role_arn
  }
}

resource "local_file" "cluster_secret_store" {
  filename = "${path.module}/rendered/cluster-secret-store.yaml"
  content = templatefile("${path.module}/manifests/cluster-secret-store.yaml.tpl", {
    aws_region = var.aws_region
  })
}

resource "local_file" "kyverno_policies" {
  filename = "${path.module}/rendered/kyverno-policies.yaml"
  content = templatefile("${path.module}/manifests/kyverno-policies.yaml.tpl", {
    cosign_public_key = var.cosign_public_key_pem
  })
}

resource "null_resource" "apply_manifests" {
  depends_on = [
    helm_release.kyverno,
    helm_release.external_secrets,
    local_file.cluster_secret_store,
    local_file.kyverno_policies,
  ]

  triggers = {
    secret_store_hash = local_file.cluster_secret_store.content_md5
    policies_hash     = local_file.kyverno_policies.content_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region} --alias tf-addons
      kubectl config use-context tf-addons
      kubectl apply -f ${local_file.cluster_secret_store.filename}
      kubectl apply -f ${local_file.kyverno_policies.filename}
    EOT
  }
}