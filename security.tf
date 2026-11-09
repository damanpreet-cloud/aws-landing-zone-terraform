data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  bucket_name  = "${var.trail_bucket_prefix}-${local.account_id}"
  trail_arn    = "arn:aws:cloudtrail:${var.home_region}:${local.account_id}:trail/${var.trail_name}"
  org_id       = aws_organizations_organization.this.id
  security_acc = aws_organizations_account.members["security"].id
}

# --- Organization CloudTrail log bucket ----------------------------------

resource "aws_s3_bucket" "trail" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "trail" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.trail.arn}/AWSLogs/${local.account_id}/*",
      "${aws_s3_bucket.trail.arn}/AWSLogs/${local.org_id}/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail.json
}

resource "aws_cloudtrail" "org" {
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.trail.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [
    aws_s3_bucket_policy.trail,
    aws_organizations_organization.this,
  ]
}

# --- GuardDuty and Security Hub: delegate administration -----------------

resource "aws_guardduty_detector" "management" {
  enable = true
}

resource "aws_guardduty_organization_admin_account" "this" {
  admin_account_id = local.security_acc

  depends_on = [
    aws_organizations_organization.this,
    aws_guardduty_detector.management,
  ]
}

resource "aws_securityhub_account" "management" {}

resource "aws_securityhub_organization_admin_account" "this" {
  admin_account_id = local.security_acc

  depends_on = [
    aws_organizations_organization.this,
    aws_securityhub_account.management,
  ]
}
