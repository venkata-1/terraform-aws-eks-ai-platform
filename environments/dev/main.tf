terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    bucket         = "ai-platform-tfstate-dev"
    key            = "dev/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "ai-platform-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "ai-platform"
      ManagedBy   = "terraform"
      Owner       = "devops-team"
    }
  }
}

# ── VPC ──────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  environment         = var.environment
  region              = var.region
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  cluster_name        = var.cluster_name
}

# ── EKS CLUSTER ──────────────────────────────────────
module "eks" {
  source = "../../modules/eks-cluster"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  environment        = var.environment

  depends_on = [module.vpc]
}

# ── NODE GROUPS ───────────────────────────────────────
module "node_groups" {
  source = "../../modules/node-groups"

  cluster_name             = module.eks.cluster_name
  cluster_version          = var.cluster_version
  node_group_role_arn      = module.iam_irsa.node_group_role_arn
  private_subnet_ids       = module.vpc.private_subnet_ids

  cpu_node_instance_types  = var.cpu_node_instance_types
  gpu_node_instance_types  = var.gpu_node_instance_types
  gpu_node_min_size        = var.gpu_node_min_size
  gpu_node_max_size        = var.gpu_node_max_size
  gpu_node_desired_size    = var.gpu_node_desired_size

  depends_on = [module.eks]
}

# ── IAM / IRSA ────────────────────────────────────────
module "iam_irsa" {
  source = "../../modules/iam-irsa"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  environment       = var.environment
  aws_account_id    = data.aws_caller_identity.current.account_id

  depends_on = [module.eks]
}

# ── S3 MODEL REGISTRY ─────────────────────────────────
module "s3_model_registry" {
  source = "../../modules/s3-model-registry"

  bucket_name  = var.model_registry_bucket
  environment  = var.environment
  versioning   = var.model_registry_versioning
  kms_key_arn  = module.secrets_manager.kms_key_arn
}

# ── SECRETS MANAGER ───────────────────────────────────
module "secrets_manager" {
  source = "../../modules/secrets-manager"

  environment      = var.environment
  cluster_name     = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

# ── ECR ───────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  environment    = var.environment
  repository_names = var.ecr_repository_names
  aws_account_id = data.aws_caller_identity.current.account_id
}

# ── OBSERVABILITY ─────────────────────────────────────
module "observability" {
  source = "../../modules/observability"

  cluster_name                = module.eks.cluster_name
  cluster_endpoint            = module.eks.cluster_endpoint
  cluster_certificate_authority = module.eks.cluster_ca
  environment                 = var.environment
  enable_cloudwatch_insights  = var.enable_cloudwatch_insights
  enable_prometheus_stack     = var.enable_prometheus_stack
  grafana_admin_password      = var.grafana_admin_password
  region                      = var.region

  depends_on = [module.node_groups]
}

data "aws_caller_identity" "current" {}
