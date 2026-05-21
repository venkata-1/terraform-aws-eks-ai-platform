environment             = "dev"
region                  = "ca-central-1"
cluster_name            = "ai-platform-dev"
cluster_version         = "1.29"

vpc_cidr                = "10.0.0.0/16"
availability_zones      = ["ca-central-1a", "ca-central-1b", "ca-central-1d"]
private_subnets         = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets          = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

cpu_node_instance_types = ["m5.xlarge", "m5.2xlarge"]
gpu_node_instance_types = ["g4dn.xlarge"]
gpu_node_min_size       = 0
gpu_node_max_size       = 4
gpu_node_desired_size   = 1

model_registry_bucket     = "ai-platform-dev-models"
model_registry_versioning = true

ecr_repository_names = [
  "llm-inference",
  "embedding-service",
  "rag-pipeline"
]

enable_cloudwatch_insights = true
enable_prometheus_stack    = true
grafana_admin_password     = "CHANGE_ME_USE_SECRETS_MANAGER"
