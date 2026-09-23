/************************************* Create CloudFront *************************************/

resource "aws_wafv2_web_acl" "js_waf" {
  name        = "js-waf"
  description = "WAF for Juice Shop CloudFront Dsitribution"
  scope       = "CLOUDFRONT"
  default_action {
    allow {}
  }

  rule {
    name     = "AWS-CommonRuleSet"
    priority = 1

    override_action {
      #   none {}
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.target_app}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 2
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.target_app}-rate-limit"
      sampled_requests_enabled   = true
    }
  }


  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.target_app}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.target_app}-waf"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }

}

resource "aws_cloudfront_distribution" "js_cdn" {
  enabled             = true
  default_root_object = ""

  web_acl_id = aws_wafv2_web_acl.js_waf.arn # 新加这一行

  origin {
    domain_name = aws_alb.js_alb.dns_name
    origin_id   = "js_alb_origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "js_alb_origin"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = true
      headers = ["Authorization"]
      cookies {
        forward = "all"
      }
    }
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.target_app}-cdn"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}






