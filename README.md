# terraform-aws-eks-ai-platform

Production-grade Terraform modules for provisioning a scalable, secure AWS EKS platform purpose-built for deploying and serving AI/ML workloads. Designed for teams running LLM inference, model training pipelines, and AI orchestration frameworks at scale.

---

## What This Does

This module set provisions a complete AWS EKS-based AI platform including:

- **EKS cluster** with managed node groups — GPU nodes (g4dn/p3) for inference, CPU nodes for supporting workloads
- **VPC architecture** — public/private subnets, NAT Gateways, VPC endpoints for ECR, S3, and Secrets Manager
- **IAM roles and IRSA** — fine-grained pod-level AWS permissions via IAM Roles for Service Accounts
- **Cluster Autoscaler** — automatic scale-out on GPU node pools during peak inference load
- **Karpenter** — fast node provisioning for bursty AI training jobs
- **AWS Secrets Manager integration** — inject model API keys, HuggingFace tokens, and OpenAI keys as Kubernetes secrets without hardcoding
- **S3 model registry** — versioned bucket for storing and loading model artifacts
- **CloudWatch Container Insights + Prometheus/Grafana** — GPU utilization, inference latency, token throughput dashboards
- **ECR repositories** — private container registry for AI model serving images with image scanning enabled

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    AWS Account                       │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │                  VPC                          │   │
│  │                                              │   │
│  │  ┌─────────────┐    ┌─────────────────────┐ │   │
│  │  │ Public      │    │ Private Subnets      │ │   │
│  │  │ Subnets     │    │                     │ │   │
│  │  │ (ALB, NAT)  │    │  EKS Node Groups    │ │   │
│  │  └─────────────┘    │  ┌───────────────┐  │ │   │
│  │                     │  │ GPU Nodes     │  │ │   │
│  │                     │  │ (Inference)   │  │ │   │
│  │                     │  ├───────────────┤  │ │   │
│  │                     │  │ CPU Nodes     │  │ │   │
│  │                     │  │ (Pipelines)   │  │ │   │
│  │                     │  └───────────────┘  │ │   │
│  │                     └─────────────────────┘ │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  S3 Model Registry   Secrets Manager   ECR           │
│  CloudWatch          Route 53          IAM/IRSA       │
└─────────────────────────────────────────────────────┘
```

---

## Folder Structure

```
terraform-aws-eks-ai-platform/
├── modules/
│   ├── vpc/                    # VPC, subnets, NAT, VPC endpoints
│   ├── eks-cluster/            # EKS control plane, OIDC, add-ons
│   ├── node-groups/            # CPU and GPU managed node groups
│   ├── karpenter/              # Karpenter provisioner for burst scaling
│   ├── iam-irsa/               # IAM roles for service accounts
│   ├── s3-model-registry/      # Versioned S3 bucket for model artifacts
│   ├── secrets-manager/        # Secrets injection via External Secrets Operator
│   ├── ecr/                    # ECR repos with lifecycle policies + scanning
│   └── observability/          # Prometheus, Grafana, CloudWatch dashboards
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── examples/
│   └── llm-inference/          # End-to-end example: deploy vLLM on GPU nodes
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml  # PR: runs fmt, validate, plan
│       └── terraform-apply.yml # Merge to main: applies to target env
└── README.md
```

---

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with appropriate IAM permissions
- kubectl
- helm >= 3.x

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/venkata-1/terraform-aws-eks-ai-platform
cd terraform-aws-eks-ai-platform/environments/dev

# Initialise
terraform init

# Review the plan
terraform plan -var-file="dev.tfvars"

# Apply
terraform apply -var-file="dev.tfvars"

# Configure kubectl
aws eks update-kubeconfig --region ca-central-1 --name ai-platform-dev
```

---

## Example: `dev.tfvars`

```hcl
environment         = "dev"
region              = "ca-central-1"
cluster_name        = "ai-platform-dev"
cluster_version     = "1.29"

# Node groups
cpu_node_instance_types  = ["m5.xlarge", "m5.2xlarge"]
gpu_node_instance_types  = ["g4dn.xlarge"]
gpu_node_min_size        = 0
gpu_node_max_size        = 4
gpu_node_desired_size    = 1

# S3 model registry
model_registry_bucket    = "ai-platform-dev-models"
model_registry_versioning = true

# Observability
enable_cloudwatch_insights = true
enable_prometheus_stack    = true
grafana_admin_password     = "CHANGE_ME"  # use Secrets Manager in prod
```

---

## GPU Node Autoscaling

The module configures Cluster Autoscaler with GPU-aware scheduling. Nodes scale to zero when idle and provision within ~3 minutes on new inference demand. Karpenter handles burst capacity for training jobs that need fast node spin-up.

```yaml
# Karpenter NodePool for GPU burst (applied automatically by module)
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: gpu-burst
spec:
  template:
    spec:
      requirements:
        - key: "node.kubernetes.io/instance-type"
          operator: In
          values: ["g4dn.xlarge", "g4dn.2xlarge", "p3.2xlarge"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["spot", "on-demand"]
```

---

## Secrets Management

Model API keys and tokens are stored in AWS Secrets Manager and synced into Kubernetes secrets using the External Secrets Operator — provisioned automatically by the `secrets-manager` module.

```hcl
# Example: inject OpenAI API key into EKS
module "secrets" {
  source          = "../../modules/secrets-manager"
  secret_name     = "ai-platform/openai-api-key"
  namespace       = "inference"
  k8s_secret_name = "openai-credentials"
}
```

---

## CI/CD Pipeline

Every pull request triggers:
1. `terraform fmt` — formatting check
2. `terraform validate` — syntax validation
3. `terraform plan` — plan output posted as PR comment via `infracost` for cost diff

Merges to `main` trigger `terraform apply` against the target environment with state stored in S3 + DynamoDB locking.

---

## Observability

The `observability` module deploys:
- **Prometheus + Grafana** via kube-prometheus-stack Helm chart
- **DCGM Exporter** — GPU metrics (utilization, memory, temperature) per node
- **Custom dashboards** for inference latency, token throughput, model error rates
- **CloudWatch Container Insights** — log aggregation and cluster-level metrics
- **PagerDuty alerting** — fires on GPU node saturation, pod OOM kills, inference p99 > threshold

---

## Security

- All nodes in private subnets — no public IPs on worker nodes
- EKS API endpoint private mode enabled in staging and prod
- IRSA used for all pod-level AWS access — no static credentials
- ECR image scanning on push — blocks deployment on CRITICAL vulnerabilities via admission webhook
- Secrets Manager rotation enabled on all AI service credentials
- VPC Flow Logs enabled and shipped to CloudWatch

---

## Contributing

Pull requests welcome. Please run `terraform fmt` and `terraform validate` before opening a PR. All changes require a passing plan in CI.

---

## Author

**Venkata Innamuri** — Senior DevOps & Cloud Engineer  
[LinkedIn](https://www.linkedin.com/in/venkata-innamuri/) | [GitHub](https://github.com/venkata-1)
