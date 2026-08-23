# Security module — Track B of the implementation plan.
#   * KMS CMKs, one per data domain (least-privilege key policies)
#   * IRSA role factory: per-service IAM roles scoped to only what each service needs
#   * Secrets Manager secret definitions (+ optional rotation) — values never in TF
#   * WAFv2 web ACL with AWS managed rule groups + rate-based rule
# Mirrors ARCHITECTURE.md §4.4 (secrets sprawl, least privilege) and §4.1.2 (WAF at edge).

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# KMS — one customer-managed key per data domain
# ---------------------------------------------------------------------------
resource "aws_kms_key" "domain" {
  for_each = toset(var.kms_key_domains)

  description             = "${var.name} CMK for ${each.key} domain"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableRootAccountAdmin"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = merge(var.tags, { Name = "${var.name}-kms-${each.key}", Domain = each.key })
}

resource "aws_kms_alias" "domain" {
  for_each      = aws_kms_key.domain
  name          = "alias/${var.name}-${each.key}"
  target_key_id = each.value.key_id
}

# ---------------------------------------------------------------------------
# IRSA role factory — per-service least-privilege roles bound to a K8s SA
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "irsa_trust" {
  for_each = var.eks_oidc_provider_arn == "" ? {} : var.irsa_service_accounts

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.eks_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.eks_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = data.aws_iam_policy_document.irsa_trust

  name               = "${var.name}-irsa-${each.key}"
  assume_role_policy = each.value.json
  tags               = merge(var.tags, { Service = each.key })
}

data "aws_iam_policy_document" "irsa_permissions" {
  for_each = var.eks_oidc_provider_arn == "" ? {} : var.irsa_service_accounts

  dynamic "statement" {
    for_each = each.value.policy_statements
    content {
      sid       = statement.value.sid
      effect    = "Allow"
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "irsa" {
  for_each = aws_iam_role.irsa

  name   = "${var.name}-irsa-${each.key}"
  role   = each.value.id
  policy = data.aws_iam_policy_document.irsa_permissions[each.key].json
}

# ---------------------------------------------------------------------------
# Secrets Manager — definitions only; values populated out-of-band
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "this" {
  for_each = var.managed_secrets

  name        = "${var.name}/${each.key}"
  description = each.value.description
  kms_key_id  = aws_kms_key.domain["secrets"].arn
  tags        = merge(var.tags, { Secret = each.key })
}

resource "aws_secretsmanager_secret_rotation" "this" {
  for_each = { for k, v in var.managed_secrets : k => v if v.rotation_lambda_arn != null }

  secret_id           = aws_secretsmanager_secret.this[each.key].id
  rotation_lambda_arn = each.value.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = each.value.rotation_days
  }
}

# ---------------------------------------------------------------------------
# WAFv2 — OWASP managed rules + rate-based + optional geo block
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "this" {
  name  = "${var.name}-web-acl"
  scope = var.waf_scope

  default_action {
    allow {}
  }

  # AWS Core rule set (OWASP top 10 coverage).
  rule {
    name     = "AWSCommonRules"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSKnownBadInputs"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSSQLi"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-sqli"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSIPReputation"
    priority = 4
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-ip-rep"
      sampled_requests_enabled   = true
    }
  }

  # Volumetric abuse guard at the edge.
  rule {
    name     = "RateLimitPerIP"
    priority = 5
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = length(var.waf_blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlock"
      priority = 6
      action {
        block {}
      }
      statement {
        geo_match_statement {
          country_codes = var.waf_blocked_countries
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, { Name = "${var.name}-web-acl" })
}
