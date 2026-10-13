# Secure baseline: every resource below passes the Trivy misconfiguration checks
# at HIGH and CRITICAL severity, which is the gate enforced by the pipeline.

# ---- Encryption key shared by the bucket and the registry ----
resource "aws_kms_key" "artifacts" {
  description             = "${var.project}-${var.environment} artifacts encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "artifacts" {
  name          = "alias/${var.project}-${var.environment}-artifacts"
  target_key_id = aws_kms_key.artifacts.key_id
}

# ---- S3 bucket that stores the pipeline's security reports ----
resource "aws_s3_bucket" "reports" {
  bucket = "${var.project}-${var.environment}-security-reports"
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket = aws_s3_bucket.reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.artifacts.arn
    }
    bucket_key_enabled = true
  }
}

# ---- Container registry: immutable tags, scan on push, KMS encryption ----
resource "aws_ecr_repository" "app" {
  name                 = "${var.project}-payments-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.artifacts.arn
  }
}

# ---- Application security group: HTTPS from a private range only ----
resource "aws_security_group" "app" {
  name        = "${var.project}-${var.environment}-payments-api"
  description = "Payments API: HTTPS from the private network only"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from the private network"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "HTTPS to the private network"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
}
