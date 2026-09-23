
/************************************* Create AWS Config *************************************/

resource "aws_s3_bucket" "js_config_bucket" {
  bucket = "js-security-config-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name        = "${var.target_app}-config-bucket"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_s3_bucket_public_access_block" "js_config_bucket_block" {
  bucket                  = aws_s3_bucket.js_config_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create bucket policy
resource "aws_s3_bucket_policy" "js_config_bucket_policy" {
  bucket = aws_s3_bucket.js_config_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "${aws_s3_bucket.js_config_bucket.arn}"
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.js_config_bucket.arn}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

#  Create Configuration Recorder
resource "aws_config_configuration_recorder" "js_recorder" {
  name     = "js-config-recorder"
  role_arn = aws_iam_role.js_config_role.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# Create Delivery Channel
resource "aws_config_delivery_channel" "js_delivery_channel" {
  name           = "js-config_delivery-channel"
  s3_bucket_name = aws_s3_bucket.js_config_bucket.bucket
  depends_on     = [aws_config_configuration_recorder.js_recorder]
}

# Start Recorder
resource "aws_config_configuration_recorder_status" "js_recorder_status" {
  name       = aws_config_configuration_recorder.js_recorder.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.js_delivery_channel]
}

# Restricted SSH
resource "aws_config_config_rule" "restricted_ssh" {
  name        = "restricted-ssh"
  description = "Checks if SSH is restricted"
  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }
  depends_on = [aws_config_configuration_recorder_status.js_recorder_status]
}

# Root Account MFA
resource "aws_config_config_rule" "root_account_mfa" {
  name        = "root-account-mfa-enabled"
  description = "Checks if root account has MFA enabled"
  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }
  depends_on = [aws_config_configuration_recorder_status.js_recorder_status]
}

# S3 Public Read
resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name        = "s3-bucket-public-read-prohibited"
  description = "Checks if S3 bucket has public read access prohibited"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
  depends_on = [aws_config_configuration_recorder_status.js_recorder_status]
}

# S3 Public Write
resource "aws_config_config_rule" "s3_bucket_public_write_prohibited" {
  name        = "s3-bucket-public-write-prohibited"
  description = "Checks if S3 bucket has public write access prohibited"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }
  depends_on = [aws_config_configuration_recorder_status.js_recorder_status]
}

# Encrypted S3 Buckets
resource "aws_config_config_rule" "encrypted_volume" {
  name        = "encrypted-volumes"
  description = "Checks if EBS volumes are encrypted"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [
    aws_config_configuration_recorder_status.js_recorder_status
  ]
}

# CloudTrail Enabled
resource "aws_config_config_rule" "cloudtrail_enabled" {
  name        = "cloudtrail-enabled"
  description = "Checks if CloudTrail is enabled"
  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }
  depends_on = [
    aws_config_configuration_recorder_status.js_recorder_status,
    aws_cloudtrail.js_cloudtrail
  ]
}
