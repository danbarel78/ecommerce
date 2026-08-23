# Observability + cost-visibility module.
#   * CloudWatch log groups per service (OTel export target, ARCHITECTURE.md §4.2)
#   * IRSA role for the OpenTelemetry collector (metrics/logs/traces export)
#   * AWS Budgets alert (Track C cost governance)

resource "aws_cloudwatch_log_group" "service" {
  for_each          = toset(var.log_groups)
  name              = "/ecommerce/${var.name}/${each.value}"
  retention_in_days = var.log_retention_days
  tags              = merge(var.tags, { Service = each.value })
}

# ---------------------------------------------------------------------------
# OTel collector IRSA role — scoped to CloudWatch + X-Ray put operations
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "otel_trust" {
  count = var.eks_oidc_provider_arn == "" ? 0 : 1

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
      values   = ["system:serviceaccount:${var.otel_namespace}:${var.otel_service_account}"]
    }
  }
}

resource "aws_iam_role" "otel" {
  count              = var.eks_oidc_provider_arn == "" ? 0 : 1
  name               = "${var.name}-otel-collector"
  assume_role_policy = data.aws_iam_policy_document.otel_trust[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "otel" {
  count = var.eks_oidc_provider_arn == "" ? 0 : 1
  name  = "${var.name}-otel-export"
  role  = aws_iam_role.otel[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:PutMetricData",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
      ]
      Resource = "*" # these actions do not support resource-level scoping
    }]
  })
}

# ---------------------------------------------------------------------------
# AWS Budgets — monthly cost alert (Track C)
# ---------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  count        = var.monthly_budget_usd > 0 ? 1 : 0
  name         = "${var.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
  }
}
