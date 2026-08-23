# Compute module — Amazon EKS. Managed Kubernetes is the portability anchor
# (ARCHITECTURE.md §4.2). On-Demand node group for critical/stateful services,
# Spot node group + Karpenter for burst/stateless (Track C). IRSA via OIDC (Track B).

data "aws_partition" "current" {}
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# ---------------------------------------------------------------------------
# Cluster IAM role
# ---------------------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${var.name}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_security_group" "cluster" {
  name        = "${var.name}-eks-cluster-sg"
  description = "EKS control plane security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-eks-cluster-sg" })
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_app_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = merge(var.tags, { Name = var.name })

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ---------------------------------------------------------------------------
# IRSA — OIDC provider so service accounts can assume scoped IAM roles
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

# ---------------------------------------------------------------------------
# Node group IAM role (shared by managed node groups)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "node" {
  name = "${var.name}-eks-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonSSMManagedInstanceCore",
  ])
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

resource "aws_security_group" "node" {
  name        = "${var.name}-eks-node-sg"
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Node-to-node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "From control plane"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name                                = "${var.name}-eks-node-sg"
    "kubernetes.io/cluster/${var.name}" = "owned"
  })
}

# ---------------------------------------------------------------------------
# Managed node groups
# ---------------------------------------------------------------------------
resource "aws_eks_node_group" "on_demand" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-on-demand"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_app_subnet_ids
  capacity_type   = "ON_DEMAND"
  instance_types  = var.on_demand_instance_types

  scaling_config {
    desired_size = var.on_demand_desired_size
    min_size     = var.on_demand_min_size
    max_size     = var.on_demand_max_size
  }

  labels = { workload = "critical" }

  tags = merge(var.tags, { Name = "${var.name}-on-demand" })

  depends_on = [aws_iam_role_policy_attachment.node]
}

resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-spot"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_app_subnet_ids
  capacity_type   = "SPOT"
  instance_types  = var.spot_instance_types

  scaling_config {
    desired_size = var.spot_desired_size
    min_size     = var.spot_min_size
    max_size     = var.spot_max_size
  }

  labels = { workload = "burst" }

  tags = merge(var.tags, { Name = "${var.name}-spot" })

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ---------------------------------------------------------------------------
# Managed addons
# ---------------------------------------------------------------------------
resource "aws_eks_addon" "this" {
  for_each      = toset(var.cluster_addons)
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = each.value
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.on_demand]
}

# ---------------------------------------------------------------------------
# Karpenter controller IRSA role (node right-sizing, §4.3.4)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "karpenter_trust" {
  count = var.enable_karpenter ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
  }
}

resource "aws_iam_role" "karpenter" {
  count              = var.enable_karpenter ? 1 : 0
  name               = "${var.name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_trust[0].json
  tags               = var.tags
}
