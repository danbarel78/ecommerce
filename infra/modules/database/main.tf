# Database module — Aurora PostgreSQL, multi-AZ, optional Global DB for DR.
# Transactional source of truth for orders/payments/customers/products
# (ARCHITECTURE.md §4.1.4, §4.3.1). "Database-per-service" is LOGICAL: services own
# separate schemas within this one cluster (§4.1.2 design note).

data "aws_secretsmanager_secret_version" "master" {
  secret_id = var.master_secret_arn
}

locals {
  # The secret is expected to store JSON {"password":"..."} — standard RDS secret shape.
  master_password = try(
    jsondecode(data.aws_secretsmanager_secret_version.master.secret_string)["password"],
    data.aws_secretsmanager_secret_version.master.secret_string,
  )
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-aurora"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-aurora-subnets" })
}

resource "aws_security_group" "aurora" {
  name        = "${var.name}-aurora-sg"
  description = "Aurora PostgreSQL access from application tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from allowed SGs"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-aurora-sg" })
}

# Global DB is the DR anchor: the regional cluster attaches to it when enabled.
resource "aws_rds_global_cluster" "this" {
  count                     = var.enable_global_db ? 1 : 0
  global_cluster_identifier = "${var.name}-global"
  engine                    = "aurora-postgresql"
  engine_version            = var.engine_version
  storage_encrypted         = true
}

resource "aws_rds_cluster" "this" {
  cluster_identifier        = "${var.name}-aurora"
  engine                    = "aurora-postgresql"
  engine_version            = var.engine_version
  database_name             = var.database_name
  master_username           = var.master_username
  master_password           = local.master_password
  db_subnet_group_name      = aws_db_subnet_group.this.name
  vpc_security_group_ids    = [aws_security_group.aurora.id]
  storage_encrypted         = true
  kms_key_id                = var.kms_key_arn
  backup_retention_period   = var.backup_retention_days
  preferred_backup_window   = "03:00-04:00"
  deletion_protection       = var.deletion_protection
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.name}-aurora-final" : null

  global_cluster_identifier = var.enable_global_db ? aws_rds_global_cluster.this[0].id : null

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.tags, { Name = "${var.name}-aurora" })

  lifecycle {
    ignore_changes = [master_password] # rotated via Secrets Manager, not TF
  }
}

# 1 writer + N replicas, round-robin across the data-subnet AZs.
resource "aws_rds_cluster_instance" "this" {
  count              = var.replica_count + 1
  identifier         = "${var.name}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn
  db_subnet_group_name            = aws_db_subnet_group.this.name

  tags = merge(var.tags, { Name = "${var.name}-aurora-${count.index}", Role = count.index == 0 ? "writer" : "reader" })
}

# ---------------------------------------------------------------------------
# RDS Proxy — connection pooling that survives writer failover (§4.4)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "proxy" {
  count = var.enable_rds_proxy ? 1 : 0
  name  = "${var.name}-rds-proxy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "proxy" {
  count = var.enable_rds_proxy ? 1 : 0
  name  = "${var.name}-rds-proxy-secret"
  role  = aws_iam_role.proxy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.master_secret_arn]
    }]
  })
}

resource "aws_db_proxy" "this" {
  count                  = var.enable_rds_proxy ? 1 : 0
  name                   = "${var.name}-aurora-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.proxy[0].arn
  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = [aws_security_group.aurora.id]
  require_tls            = true

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED"
    secret_arn  = var.master_secret_arn
  }

  tags = merge(var.tags, { Name = "${var.name}-aurora-proxy" })
}

resource "aws_db_proxy_default_target_group" "this" {
  count         = var.enable_rds_proxy ? 1 : 0
  db_proxy_name = aws_db_proxy.this[0].name

  connection_pool_config {
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "this" {
  count                 = var.enable_rds_proxy ? 1 : 0
  db_proxy_name         = aws_db_proxy.this[0].name
  target_group_name     = aws_db_proxy_default_target_group.this[0].name
  db_cluster_identifier = aws_rds_cluster.this.id
}
