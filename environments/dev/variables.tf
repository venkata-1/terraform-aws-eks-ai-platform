variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ca-central-1a", "ca-central-1b", "ca-central-1d"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "cpu_node_instance_types" {
  description = "EC2 instance types for CPU node group"
  type        = list(string)
  default     = ["m5.xlarge", "m5.2xlarge"]
}

variable "gpu_node_instance_types" {
  description = "EC2 instance types for GPU node group"
  type        = list(string)
  default     = ["g4dn.xlarge"]
}

variable "gpu_node_min_size" {
  description = "Minimum GPU nodes"
  type        = number
  default     = 0
}

variable "gpu_node_max_size" {
  description = "Maximum GPU nodes"
  type        = number
  default     = 4
}

variable "gpu_node_desired_size" {
  description = "Desired GPU nodes"
  type        = number
  default     = 1
}

variable "model_registry_bucket" {
  description = "S3 bucket name for model artifacts"
  type        = string
}

variable "model_registry_versioning" {
  description = "Enable S3 versioning for model registry"
  type        = bool
  default     = true
}

variable "ecr_repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["llm-inference", "embedding-service", "rag-pipeline"]
}

variable "enable_cloudwatch_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_prometheus_stack" {
  description = "Deploy kube-prometheus-stack via Helm"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password — use Secrets Manager in prod"
  type        = string
  sensitive   = true
}
