output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_certificate_authority" {
  description = "EKS cluster CA data"
  value       = module.eks.cluster_ca
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "model_registry_bucket" {
  description = "S3 model registry bucket name"
  value       = module.s3_model_registry.bucket_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "grafana_endpoint" {
  description = "Grafana dashboard URL"
  value       = module.observability.grafana_endpoint
}
