# Velero backup bucket (CDE storage). Versioned, SSE-KMS, public access blocked,
# replicated to dr_region. See decisions/0008-velero-backup-dr.md.

resource "aws_s3_bucket" "velero" {
  bucket = "${var.cluster_name}-velero-${data.aws_caller_identity.current.account_id}"
  tags   = merge(local.tags, { PCIScope = "cde" })
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket                  = aws_s3_bucket.velero.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = var.velero_backup_expiration_days
    }
  }
}

resource "aws_s3_bucket" "velero_replica" {
  provider = aws.dr
  bucket   = "${var.cluster_name}-velero-replica-${data.aws_caller_identity.current.account_id}"
  tags     = merge(local.tags, { PCIScope = "cde", ReplicaOf = aws_s3_bucket.velero.id })
}

resource "aws_s3_bucket_versioning" "velero_replica" {
  provider = aws.dr
  bucket   = aws_s3_bucket.velero_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "velero_replica" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.velero_replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "audit_dr" {
  provider                = aws.dr
  description             = "Velero replica encryption for ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(local.tags, { PCIScope = "cde" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero_replica" {
  provider = aws.dr
  bucket   = aws_s3_bucket.velero_replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit_dr.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_iam_role" "s3_replication" {
  name = "${var.cluster_name}-velero-replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "s3_replication" {
  name = "${var.cluster_name}-velero-replication"
  role = aws_iam_role.s3_replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
        ]
        Resource = aws_s3_bucket.velero.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
        ]
        Resource = "${aws_s3_bucket.velero.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ]
        Resource = "${aws_s3_bucket.velero_replica.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = aws_kms_key.audit.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey",
        ]
        Resource = aws_kms_key.audit_dr.arn
      },
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "velero" {
  depends_on = [aws_s3_bucket_versioning.velero, aws_s3_bucket_versioning.velero_replica]

  bucket = aws_s3_bucket.velero.id
  role   = aws_iam_role.s3_replication.arn

  rule {
    id     = "to-dr"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.velero_replica.arn
      storage_class = "STANDARD_IA"
      encryption_configuration {
        replica_kms_key_id = aws_kms_key.audit_dr.arn
      }
    }
    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }
  }
}
