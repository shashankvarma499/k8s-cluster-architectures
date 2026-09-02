# Two CMKs we own (EKS secrets encryption is created by terraform-aws-eks):
#   vault — auto-unseal for the in-cluster Vault Raft cluster.
#   audit — CloudWatch log groups (VPC flow) and Velero SSE-KMS.

data "aws_iam_policy_document" "kms_admin" {
  statement {
    sid       = "EnableIAMRoot"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

data "aws_iam_policy_document" "kms_logs" {
  source_policy_documents = [data.aws_iam_policy_document.kms_admin.json]

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "vault" {
  description             = "Vault auto-unseal for ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_admin.json
  tags                    = merge(local.tags, { PCIScope = "cde" })
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${var.cluster_name}-vault"
  target_key_id = aws_kms_key.vault.key_id
}

resource "aws_kms_key" "audit" {
  description             = "Audit / backup encryption for ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_logs.json
  tags                    = local.tags
}

resource "aws_kms_alias" "audit" {
  name          = "alias/${var.cluster_name}-audit"
  target_key_id = aws_kms_key.audit.key_id
}
