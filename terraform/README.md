# Infrastructure as Code: Currency Converter GitOps Platform

This repository contains the production-grade Terraform configuration that automates the foundational cloud infrastructure for the **Currency Converter GitOps Pipeline**.

This code translates the manual infrastructure provisioning steps (Phase 1 and the AWS-specific parts of Phase 2) of the FinacPlus Case Study into declarative, version-controlled Infrastructure as Code (IaC). It provisions the network, the Kubernetes cluster, the CI management server, container registries, and vital IAM security bindings.

---

## 📖 Table of Contents

1. [What This Creates (Module Breakdown)](#1-what-this-creates-module-breakdown)
2. [What This Does NOT Create (Scope Limits)](#2-what-this-does-not-create-scope-limits)
3. [Prerequisites & Environment Setup](#3--prerequisites--environment-setup)
4. [Step-by-Step Deployment Guide](#4-step-by-step-deployment-guide)
5. [Post-Deployment Handoff (Manual Steps)](#5-post-deployment-handoff-manual-steps)
6. [Design Decisions & Trade-Offs](#6-design-decisions--trade-offs)
7. [Troubleshooting Guide](#7--troubleshooting-guide)


## 1. What This Creates (Module Breakdown)
This project is highly modularized, adopting a standard structure consisting of a root module (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `providers.tf`) and specialized sub-modules. It strictly focuses on the underlying AWS and Kubernetes platform required to support a secure DevSecOps workflow.

| Module       | Description & Phase Mapping                                                                                                                                                                                                                                                      |
|--------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `networking` | Provisions a custom VPC (10.0.0.0/16) across 2 Availability Zones, Public/Private subnets, and a NAT Gateway to securely host the EKS cluster. Required tags for the AWS Load Balancer Controller are automatically injected.                                                    |
| `eks`        | Provisions the Amazon EKS cluster (v1.30) with a managed Node Group (`t3.medium`). Crucially, it enables the OIDC provider (`--with-oidc` equivalent) allowing IAM Roles for Service Accounts (IRSA) to function.                                                                |
| `ecr`        | Creates the `currency-converter-app` private Amazon Elastic Container Registry. It configures AES-256 encryption, enables push-time scanning, and attaches an automated 14-day lifecycle cleanup policy for untagged images.                                                     |
| `jenkins`    | Provisions an EC2 instance (`m7i-flex.large`), attaches strict Security Groups (Phase 1.2), binds the `Jenkins-ECR-Push-Role` (Phase 1.1), and bootstraps the entire DevSecOps toolchain (Java 21, Docker, AWS CLI, Trivy, Cosign, GH CLI) via a `user_data` script (Phase 1.4). |
| `irsa`       | Provisions the specific IAM roles mapping AWS permissions to Kubernetes ServiceAccounts via OIDC. This includes Kyverno's read-only ECR access to verify Cosign signatures, and External Secrets Operator's read-only access to AWS Secrets Manager.                             |
| `addons`     | Bootstraps cluster-side tooling using Helm and `kubectl`. This installs ArgoCD, Kyverno, and the External Secrets Operator. It also applies the `ClusterSecretStore` and custom Kyverno security policies.                                                                       |

---

## 2. What This Does NOT Create (Scope Limits)

To maintain a clean separation of concerns between Infrastructure provisioning and CI/CD application logic, this Terraform setup intentionally omits the following:

**1. Application & Configuration Source Code:** The [gitops-config-cc-app](github.com/Prajwalkadam29/gitops-config-cc-app/), [currency-converter](https://github.com/Prajwalkadam29/currency-converter), and [jenkins-shared-library](https://github.com/Prajwalkadam29/currency-converter) GitHub repositories are managed as regular Git repos, not infrastructure.

**2. Jenkins Internal Job Configuration:** Jenkins credentials, the Multibranch pipeline job itself, SonarQube tokens, and SMTP settings are not managed here. Jenkins lacks a clean, native Terraform provider for these tasks without heavy community plugins. These remain manual UI steps (Operational Manual Sections 1.3 and 2.3-2.9).

**3. Cryptographic Key Generation:** The `cosign.key` private key and its passphrase are generated manually (`cosign generate-key-pair`) and stored directly in the Jenkins Credential Store. They are never committed to Terraform state or version control to preserve Zero-Trust principles.

---

## 3. 🛠️ Prerequisites & Environment Setup

### Where to run this?

This project should be executed from your local development machine (macOS, Linux, or WSL on Windows) or a dedicated administrative bastion host. It should not be run from the Jenkins server itself, as the Jenkins server is one of the resources being created.

### Required Tools

Ensure the following tools are installed on your execution environment:

1. **Terraform (>= 1.7.0):** Install Guide
2. **AWS CLI v2:** Authenticated via `aws configure` or an SSO profile. Install Guide
3. **kubectl:** Required for verifying cluster status and the `local-exec` provisioner. Install Guide
4. **Helm:** Required for addons. Install Guide
5. **Cosign:** Required locally only to generate your public key payload if you haven't already (`cosign generate-key-pair`).


### AWS Account Preparation

1. **AWS Credentials:** You must be authenticated to AWS with Administrator privileges.
2. **EC2 Key Pair:** You must have an existing EC2 SSH Key Pair in the ap-south-1 region for Jenkins SSH access.
3. **Cosign Public Key:** Generate a cryptographic key pair locally:

   ```bash
   cosign generate-key-pair
   ```

**Note:** Keep cosign.key strictly secret. You will paste the contents of cosign.pub into Terraform.

---

## 4. Step-by-Step Deployment Guide

### Step 1: Configure Variables
Clone the repository and navigate to the `terraform` directory. Copy the example variables file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```


Open `terraform.tfvars` in a text editor and fill in the strictly required fields:
* `jenkins_key_pair_name`: The exact name of your AWS EC2 Key Pair in `ap-south-1`.
* `jenkins_allowed_ssh_cidr`: Your local IP address (e.g., `203.0.113.50/32`) or `0.0.0.0/0` for open access.
* `cosign_public_key_pem`: Paste the exact contents of your `cosign.pub` file, including the `BEGIN PUBLIC KEY` and `END PUBLIC KEY` headers.


### Step 2: Initialize Terraform
Initialize the working directory to download the required AWS, Kubernetes, Helm, and Local provider plugins defined in `versions.tf`:
   ```bash
   terraform init
   ```


### Step 3: Plan the Deployment
Generate an execution plan to verify exactly what resources Terraform will create. Review this carefully to ensure no existing resources will be unexpectedly modified.
   ```bash
   terraform plan
   ```


### Step 4: Apply the Infrastructure

Execute the deployment.
   ```bash
   terraform apply
   ```

(Type `yes` when prompted to confirm).

**Note:** This process takes approximately **15-20 minutes**. Provisioning the EKS control plane and the managed node group are time-intensive AWS operations. Do not interrupt the terminal during this phase.

---

## 5. Post-Deployment Handoff (Manual Steps)

Once terraform apply completes successfully, Terraform will output the commands needed to access your new infrastructure.

### 1. Connect to the EKS Cluster
Run the outputted command to update your local `kubeconfig`:
```bash
$(terraform output -raw configure_kubectl)
```


Verify the cluster add-ons successfully initialized:

```bash
kubectl get pods -n argocd
kubectl get pods -n kyverno
kubectl get pods -n external-secrets
```


### 2. Access the Jenkins Server

Retrieve the Jenkins UI URL:
   ```bash
   echo "http://$(terraform output -raw jenkins_public_ip):8080"
   ```

**_Note:_** Because Jenkins is downloading and installing Java, Docker, AWS CLI, Trivy, Cosign, and other tools via the `bootstrap.sh` user-data script, it may take 3-5 minutes after EC2 creation for the web interface to become available.


### 3. Proceed to Manual Configuration (Phase 2)

Terraform has prepared the entire underlying cloud environment. You must now transition to the **Operational Manual** (Sections 1.3 and 2.3 - 2.9) to complete the setup:

1. Unlock Jenkins via SSH (sudo cat /var/lib/jenkins/secrets/initialAdminPassword).
2. Install suggested Jenkins plugins and create the Admin user.
3. Add the `AWS_ACCOUNT_ID` global environment variable.
4. Generate and bind the GitHub PAT, Cosign Keys, SonarQube Token, and SMTP passwords into the Jenkins Credential Store.
5. Apply the ArgoCD ApplicationSet to trigger GitOps synchronization:
   ```bash
   kubectl apply -f argocd-appset/appset.yaml
   ```

---

## 6. Design Decisions & Trade-Offs

To demonstrate engineering maturity and adherence to SRE best practices, several deliberate architectural trade-offs were made and documented:


**1. Provider Authentication (providers.tf):**
The Kubernetes and Helm providers authenticate to the newly created EKS cluster using the AWS CLI exec plugin (`aws eks get-token`). This is a massive security benefit: it eliminates the need to generate, manage, or store long-lived `kubeconfig` files or static bearer tokens on the executing machine.

**2. Secrets Out of State (Security Posture):**
Jenkins credentials (GitHub PAT, Cosign private keys, SonarQube tokens) are intentionally not managed by Terraform. Injecting sensitive authentication tokens into `.tfvars` places them in plain-text inside the Terraform state file (`terraform.tfstate`), which is a major security anti-pattern. They are safely delegated to the manual Jenkins Credential Store setup.

**3. local-exec for Kubernetes CRDs (Reliability Workaround):**
The Kyverno Policies and `ClusterSecretStore` manifests are applied via a `local-exec` provisioner inside a `null_resource`, rather than using the native `kubernetes_manifest` resource. The native resource requires Custom Resource Definitions (CRDs) to exist during the `terraform plan` phase. Since those CRDs are installed by the Helm charts in the same run, it causes a "chicken-and-egg" validation failure. local-exec gracefully bridges this gap at the minor expense of "pure" Terraform state management.

**4. Single NAT Gateway (Cost Optimization):**
For this environment, `single_nat_gateway = true` was utilized in the networking module. While a highly available (HA) production environment standardizes on one NAT Gateway per Availability Zone, a single gateway was chosen here to minimize idle AWS hourly charges while maintaining the exact same private routing architecture required for the EKS nodes.

**5. State Management (versions.tf):**
As configured in `versions.tf`, the project uses local state to get started quickly. For a true, long-term production environment, this should be migrated to the commented-out S3 backend with DynamoDB locking to prevent state corruption across a multi-engineer team.

---

## 7. 🚑 Troubleshooting Guide

### 1. terraform apply fails during the null_resource.apply_manifests step

* **Symptom:** Error stating the server doesn't have a resource type "ClusterSecretStore" or connection refused.
* **Cause:** The External Secrets Operator Helm chart takes a few seconds to register its CRDs with the Kubernetes API, or the EKS endpoint is temporarily sluggish immediately after creation. The local-exec script might have fired milliseconds before the API was ready.
* **Fix:** Simply re-run terraform apply. Terraform is idempotent and will pick up right where it left off, successfully applying the manifests on the second try.


### 2. Cannot access the Jenkins UI on port 8080

* **Symptom:** The browser times out connecting to the EC2 Public IP.

* **Cause 1:** The `bootstrap.sh` script is still running.
    * **Fix:** SSH into the instance (`ssh -i your-key.pem ubuntu@<IP>`) and tail the logs: `tail -f /var/log/cloud-init-output.log`. Wait for it to finish.

* **Cause 2:** Security Group CIDR block is too restrictive.
  * **Fix:** Ensure `jenkins_allowed_ssh_cidr` in `terraform.tfvars` includes your current public IP address, or set it to `0.0.0.0/0` temporarily.


### 3. kubectl returns "Unauthorized" or "You must be logged in to the server"

* **Symptom:** Running `kubectl get nodes` fails with an auth error after running the configuration command.
* **Cause:** AWS EKS maps cluster admin rights to the exact IAM User or Role that created the cluster (the credentials used to run Terraform).
* **Fix:** Ensure your AWS CLI (`aws configure`) is using the exact same profile/credentials used to run `terraform apply`. Run `aws sts get-caller-identity` to verify who you are currently logged in as.

---
