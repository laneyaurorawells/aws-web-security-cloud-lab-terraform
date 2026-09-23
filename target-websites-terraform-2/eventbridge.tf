# Create SNS Topic
resource "aws_sns_topic" "js_security_alerts" {
    name = "js-security-alerts"
    tags = {
        Name = "${var.target_app}-security-alerts"
        Environment = "dev"
        Project     = "${var.target_app} Terraform 2.0"
    }
}

resource "aws_sns_topic_subscription" "js_security_email" {
    topic_arn = aws_sns_topic.js_security_alerts.arn
    protocol = "email"
    endpoint = "laney.aurora.wells@pm.me"
}

resource "aws_cloudwatch_event_rule" "js_security_hub_findings" {
    name = "js-security-hub-findings"
    description = "Send High and Critical Security Hub Findings to SNS"

    event_pattern = jsonencode({
    source = [
            "aws.securityhub"
    ] 

    "detail-type" = [
        "Security Hub Findings - Imported"
    ]

    detail = {
        findings = {
            RecordState = [
            "ACTIVE"
        ]

            Severity = {
                Label = [
                "HIGH",
                "CRITICAL"
                ]
            }
            }
        }
    })

    tags = {
        Name = "${var.target_app}-security-hub-findings"
        Environment = "dev"
    }
}

resource "aws_cloudwatch_event_target" "js_security_alerts_sns" {
    rule = aws_cloudwatch_event_rule.js_security_hub_findings.name
    target_id = "SendSecurityAlertToSNS"
    arn = aws_sns_topic.js_security_alerts.arn

}

data "aws_iam_policy_document" "js_security_alerts_sns_policy" {
    statement {
        effect = "Allow"

        actions = [
            "SNS:Publish"
        ]

        principals {
            type = "Service"
            identifiers = ["events.amazonaws.com"]
        }

        resources = [
            aws_sns_topic.js_security_alerts.arn
        ]

        condition {
            test = "ArnEquals"
            variable = "aws:SourceArn"
            values = [
                aws_cloudwatch_event_rule.js_security_hub_findings.arn
            ]
        }
    }
}

resource "aws_sns_topic_policy" "js_security_alerts_sns_policy" {
    arn = aws_sns_topic.js_security_alerts.arn
    policy = data.aws_iam_policy_document.js_security_alerts_sns_policy.json
}