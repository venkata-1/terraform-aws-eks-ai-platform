# ── NODE GROUP IAM ROLE ───────────────────────────────
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node_group.name
}

# ── CPU NODE GROUP ────────────────────────────────────
resource "aws_eks_node_group" "cpu" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-cpu"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.cpu_node_instance_types
  version         = var.cluster_version

  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.cpu.id
    version = aws_launch_template.cpu.latest_version
  }

  labels = {
    role        = "cpu-workloads"
    environment = var.environment
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  tags = { Name = "${var.cluster_name}-cpu-node-group" }
}

resource "aws_launch_template" "cpu" {
  name_prefix = "${var.cluster_name}-cpu-"
  description = "Launch template for CPU node group"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 required
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = true }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster_name}-cpu-node"
      Environment = var.environment
    }
  }
}

# ── GPU NODE GROUP ────────────────────────────────────
resource "aws_eks_node_group" "gpu" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-gpu"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.gpu_node_instance_types
  version         = var.cluster_version

  scaling_config {
    desired_size = var.gpu_node_desired_size
    max_size     = var.gpu_node_max_size
    min_size     = var.gpu_node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.gpu.id
    version = aws_launch_template.gpu.latest_version
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    role                 = "gpu-inference"
    "nvidia.com/gpu"     = "true"
    environment          = var.environment
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  tags = { Name = "${var.cluster_name}-gpu-node-group" }
}

resource "aws_launch_template" "gpu" {
  name_prefix = "${var.cluster_name}-gpu-"
  description = "Launch template for GPU inference node group"

  # GPU-optimized EKS AMI with NVIDIA drivers
  image_id = data.aws_ssm_parameter.gpu_ami.value

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = true }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster_name}-gpu-node"
      Environment = var.environment
      NodeType    = "gpu-inference"
    }
  }
}

data "aws_ssm_parameter" "gpu_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2-gpu/recommended/image_id"
}
