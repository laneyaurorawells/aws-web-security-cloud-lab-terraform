resource "aws_securityhub_account" "js_security_hub" {
  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "js_security_standards_fsbp" {
  depends_on = [
    aws_securityhub_account.js_security_hub
  ]
  standards_arn = "arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "js_security_standards_cis" {
  depends_on = [
    aws_securityhub_account.js_security_hub
  ]
    
    standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
}