# Cache + Search module.
#   Redis (ElastiCache)  -> sessions, cart, hot-product cache, stock-reservation counters
#                           (ARCHITECTURE.md §4.1.4, §4.2)
#   OpenSearch           -> catalog / faceted search projection (§4.2)
# Both multi-AZ, encrypted in transit + at rest.

data "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id = var.redis_auth_secret_arn
}

# ---------------------------------------------------------------------------
# ElastiCache Redis (cluster mode, multi-AZ)
# ---------------------------------------------------------------------------
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name}-redis"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis-sg"
  description = "Redis access from application tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from allowed SGs"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-redis-sg" })
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.name}-redis"
  description          = "${var.name} Redis (sessions/cart/hot cache/stock counters)"
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  port                 = 6379

  num_node_groups         = var.redis_num_node_groups
  replicas_per_node_group = var.redis_replicas_per_node_group

  automatic_failover_enabled = var.redis_replicas_per_node_group >= 1
  multi_az_enabled           = var.redis_replicas_per_node_group >= 1

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_cache_key_arn
  transit_encryption_enabled = true
  auth_token                 = data.aws_secretsmanager_secret_version.redis_auth.secret_string

  snapshot_retention_limit = 7

  tags = merge(var.tags, { Name = "${var.name}-redis" })

  lifecycle {
    ignore_changes = [auth_token] # rotated via Secrets Manager
  }
}

# ---------------------------------------------------------------------------
# OpenSearch (multi-AZ, zone-aware)
# ---------------------------------------------------------------------------
resource "aws_security_group" "opensearch" {
  name        = "${var.name}-opensearch-sg"
  description = "OpenSearch access from application tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from allowed SGs"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-opensearch-sg" })
}

resource "aws_opensearch_domain" "this" {
  domain_name    = "${var.name}-search"
  engine_version = var.opensearch_engine_version

  cluster_config {
    instance_type          = var.opensearch_instance_type
    instance_count         = var.opensearch_instance_count
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = var.opensearch_az_count
    }
  }

  vpc_options {
    subnet_ids         = slice(var.subnet_ids, 0, var.opensearch_az_count)
    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_search_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  tags = merge(var.tags, { Name = "${var.name}-search" })
}
