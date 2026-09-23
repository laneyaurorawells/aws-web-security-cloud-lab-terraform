/************************************* Create EC2 Instance Profile*************************************/


resource "aws_iam_role" "js_ec2_ssm_role" {
  name = "js-ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "js_ec2_ssm_attach" {
  role       = aws_iam_role.js_ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "js_ec2_cwagent_attach" {
  role       = aws_iam_role.js_ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "js_ec2_ssm_profile" {
  name = "js-ec2-ssm-profile"
  role = aws_iam_role.js_ec2_ssm_role.name
}





resource "aws_iam_role" "js_vpc_flow_log_cw_group_role" {
  name = "js-vpc-flow-log-cw-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.target_app}-vpc-flow-log-role"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_iam_role_policy" "js_vpc_flow_log_cw_group_policy" {
  name = "js-vpc-flow-log-cw-group-policy"
  role = aws_iam_role.js_vpc_flow_log_cw_group_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "js_cloudtrail_cw_role" {
  name = "js-cloudtrail-cw-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "js_cloudtrail_cw_role_policy" {
  role = aws_iam_role.js_cloudtrail_cw_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.js_cloudtrail_cw_logs.arn}:*"
    }
  })
}

# Create IAM Role for AWS Config to read and record configuraiton of various kinds of AWS Services
resource "aws_iam_role" "js_config_role" {
  name = "js-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name        = "${var.target_app}-config-role"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

# Attach permission to the IAM role created above
resource "aws_iam_role_policy_attachment" "js_config_role_policy" {
  role       = aws_iam_role.js_config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}