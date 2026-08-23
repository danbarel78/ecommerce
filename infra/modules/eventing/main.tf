# Eventing module — Amazon MSK (managed Kafka), the event backbone.
# Every state change flows through Kafka; consumers own their projections
# (ARCHITECTURE.md §4.1.4, §4.3.3). Cross-region replication closes the DR gap in §4.1.3.

resource "aws_security_group" "msk" {
  name        = "${var.name}-msk-sg"
  description = "MSK broker access from application tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Kafka TLS from allowed SGs"
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  ingress {
    description     = "Kafka IAM auth from allowed SGs"
    from_port       = 9098
    to_port         = 9098
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-msk-sg" })
}

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/msk/${var.name}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_msk_cluster" "this" {
  cluster_name           = "${var.name}-msk"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.broker_count

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_ebs_size
      }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = var.kms_key_arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-msk" })
}

# ---------------------------------------------------------------------------
# DR replication — MSK Replicator to a DR-region cluster (§4.1.3 gap fix)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "replicator" {
  count = var.enable_dr ? 1 : 0
  name  = "${var.name}-msk-replicator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "kafka.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_msk_replicator" "this" {
  count                  = var.enable_dr ? 1 : 0
  replicator_name        = "${var.name}-replicator"
  description            = "Cross-region replication to DR MSK cluster"
  service_execution_role_arn = aws_iam_role.replicator[0].arn

  kafka_cluster {
    amazon_msk_cluster {
      msk_cluster_arn = aws_msk_cluster.this.arn
    }
    vpc_config {
      subnet_ids         = var.subnet_ids
      security_groups_ids = [aws_security_group.msk.id]
    }
  }

  kafka_cluster {
    amazon_msk_cluster {
      msk_cluster_arn = var.dr_broker_arn
    }
    vpc_config {
      subnet_ids         = var.subnet_ids
      security_groups_ids = [aws_security_group.msk.id]
    }
  }

  replication_info_list {
    source_kafka_cluster_arn = aws_msk_cluster.this.arn
    target_kafka_cluster_arn = var.dr_broker_arn
    target_compression_type  = "NONE"

    topic_replication {
      topics_to_replicate = ["*"]
    }

    consumer_group_replication {
      consumer_groups_to_replicate = ["*"]
    }
  }

  tags = var.tags
}
