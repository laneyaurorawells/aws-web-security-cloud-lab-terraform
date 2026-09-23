
/************************************* Create CloudTrail *************************************/

resource "aws_s3_bucket" "js_cloudtrail_s3_bucket" {
  bucket        = "js-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "${var.target_app}-cloudtrail-s3-bucket"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }

}

resource "aws_s3_bucket_public_access_block" "js_cloudtrail_s3_bucket_block" {
  bucket = aws_s3_bucket.js_cloudtrail_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "js_cloudtrail_s3_bucket_policy" {
  bucket = aws_s3_bucket.js_cloudtrail_s3_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.js_cloudtrail_s3_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.js_cloudtrail_s3_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]

  })
}

resource "aws_cloudwatch_log_group" "js_cloudtrail_cw_logs" {
  name              = "/aws/cloudtrail/js-cloudtrail"
  retention_in_days = 7
}



resource "aws_cloudtrail" "js_cloudtrail" {
  name                          = "js-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.js_cloudtrail_s3_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.js_cloudtrail_cw_logs.arn}"

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.js_cloudtrail_cw_logs.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.js_cloudtrail_cw_role.arn

  depends_on = [
    aws_s3_bucket_policy.js_cloudtrail_s3_bucket_policy,
    aws_iam_role.js_cloudtrail_cw_role,
    aws_iam_role_policy.js_cloudtrail_cw_role_policy
  ]
}