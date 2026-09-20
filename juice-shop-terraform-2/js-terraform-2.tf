data "aws_caller_identity" "current" {}

variable "target_app" {
    description = "Which Vulnerable target application to deploy: juice_shop, mutillidae, vuln_bank, or altoroj"
    type = string
    default = "juice_shop"

    validation {
        condition = contains(["juice_shop", "mutillidae", "vuln_bank", "altoroj"], var.target_app)
        error_message = "target_app must be one of \"juice_shop\", \"mutillidae\", \"vuln_bank\", \"altoroj\""
    }
}

locals {
    app_options = {
        juice_shop = {
            deploy_type = "docker_run"
            docker_image = "bkimminich/juice-shop"
            container_port = 3000
            git_repo = ""
            health_check_path = "/"
        }
        mutillidae = {
            deploy_type = "docker_run"
            docker_image = "citizenstig/nowasp"
            container_port = 80
            git_repo = ""
            health_check_path = "/"
        }
        vuln_bank = {
            deploy_type = "compose"
            docker_image = ""
            container_port = 5000
            git_repo = "https://github.com/Commando-X/vuln-bank.git"
            health_check_path = "/"
        }
        altoroj = {
            deploy_type = "docker_run"
            docker_image = "jasonhubs/altoroj:3.1.1"
            container_port = 8080
            git_repo = ""
            health_check_path = "/altoroj/"
        }
    }

    selected_app = local.app_options[var.target_app]

    user_data_rendered = templatefile("${path.module}/templates/userdata.sh.tpl", {
        deploy_type = local.selected_app.deploy_type
        docker_image = local.selected_app.docker_image
        container_port = local.selected_app.container_port
        git_repo = local.selected_app.git_repo
    })

    app_host_port = 80
}

resource "aws_vpc" "js_vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name        = "js-vpc"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

resource "aws_subnet" "js_public_subnet_1" {
    cidr_block = "10.0.1.0/24"
    vpc_id = aws_vpc.js_vpc.id
    availability_zone = "us-east-1a"

    tags = {
        Name        = "js-public-subnet-1"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

resource "aws_subnet" "js_public_subnet_2" {
    cidr_block = "10.0.2.0/24"
    vpc_id = aws_vpc.js_vpc.id
    availability_zone = "us-east-1b"

    tags = {
        Name        = "js-public-subnet-2"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

resource "aws_subnet" "js_private_subnet_1" {
    cidr_block = "10.0.3.0/24"
    vpc_id = aws_vpc.js_vpc.id
    availability_zone = "us-east-1a"

    tags = {
        Name        = "js-private-subnet-1"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

resource "aws_subnet" "js_private_subnet_2" {
    cidr_block = "10.0.4.0/24"
    vpc_id = aws_vpc.js_vpc.id
    availability_zone = "us-east-1b"

    tags = {
        Name        = "js-private-subnet-2"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

# Add Internet Gateway
resource "aws_internet_gateway" "js-igw" {
    vpc_id = aws_vpc.js_vpc.id

    tags = {
        Name        = "js-igw"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
  }
}

resource "aws_route_table" "js_public_rt" {
    vpc_id = aws_vpc.js_vpc.id

    tags = {
        Name        = "js-public-rt"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

resource "aws_route" "js_public_rt_route_1" {
    route_table_id = aws_route_table.js_public_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.js-igw.id  
}

resource "aws_route_table_association" "js_public_rt_association_1" {
    route_table_id = aws_route_table.js_public_rt.id
    subnet_id = aws_subnet.js_public_subnet_1.id
}

resource "aws_route_table_association" "js_public_rt_association_2" {
    route_table_id = aws_route_table.js_public_rt.id
    subnet_id = aws_subnet.js_public_subnet_2.id
}

# Add NAT Gateway
resource "aws_eip" "js_nat_eip" {
    domain = "vpc"
}

resource "aws_nat_gateway" "js_ngw" {
    allocation_id = aws_eip.js_nat_eip.id
    subnet_id = aws_subnet.js_public_subnet_1.id

    tags = {
        Name        = "js-ngw"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }

    depends_on = [aws_internet_gateway.js-igw] 
}

resource "aws_route_table" "js_private_rt" {
    vpc_id = aws_vpc.js_vpc.id

    tags = {
        Name        = "js-private-rt"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

resource "aws_route" "js_private_rt_route_1" {
    route_table_id = aws_route_table.js_private_rt.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.js_ngw.id
}

resource "aws_route_table_association" "js_private_route_table_association_1" {
    route_table_id = aws_route_table.js_private_rt.id
    subnet_id = aws_subnet.js_private_subnet_1.id
}

resource "aws_route_table_association" "js_private_route_table_association_2" {
    route_table_id = aws_route_table.js_private_rt.id
    subnet_id = aws_subnet.js_private_subnet_2.id
}

/************************************* Create EC2 Security Group*************************************/
resource "aws_security_group" "js_sg" {
    vpc_id = aws_vpc.js_vpc.id
    
    tags = {
        Name        = "js-sg"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_allow_alb_sg_only" {
    security_group_id = aws_security_group.js_sg.id
    referenced_security_group_id = aws_security_group.js_alb_sg.id
    from_port = local.app_host_port
    to_port = local.app_host_port
    ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_allow_all_outbound" {
  security_group_id = aws_security_group.js_sg.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol        = "-1"
}


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

/************************************* Create EC2 *************************************/

data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "js_ubuntu_ec_1" {
  ami           = data.aws_ssm_parameter.amazon_linux.value
  instance_type = "t2.micro"
  vpc_security_group_ids = [
    aws_security_group.js_sg.id
  ]

  subnet_id = aws_subnet.js_private_subnet_1.id

#   associate_public_ip_address = true

#   iam_instance_profile = aws_iam_instance_profile.cwagent_profile.name
    iam_instance_profile = aws_iam_instance_profile.js_ec2_ssm_profile.name

user_data = local.user_data_rendered

  tags = {
    Name        = "${var.target_app}-ec-1"
    Environment = "dev"
    Project     = "Juice Shop Terraform 2.0"
  }
 
    depends_on = [ aws_nat_gateway.js_ngw ]
  
}


resource "aws_instance" "js_ubuntu_ec_2" {
  ami           = data.aws_ssm_parameter.amazon_linux.value
  instance_type = "t2.micro"
  vpc_security_group_ids = [
    aws_security_group.js_sg.id
  ]

  subnet_id = aws_subnet.js_private_subnet_2.id

iam_instance_profile = aws_iam_instance_profile.js_ec2_ssm_profile.name

user_data = local.user_data_rendered         

  tags = {
    Name        = "${var.target_app}-ec-2"
    Environment = "dev"
    Project     = "Juice Shop Terraform 2.0"
  }
 
    depends_on = [ aws_nat_gateway.js_ngw ]
  
}

/************************************* Create VPC Flow Logs *************************************/

resource "aws_cloudwatch_log_group" "js_vpc_flow_log_cw_group" {
    name = "/aws/js-vpc/js-flow-logs"
    retention_in_days = 7

    tags = {
        Name        = "js-vpc-flow-logs"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
  }
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
        Name = "js-vpc-flow-log-role"
        Environment = "dev"
        Project = "Juice Shop Terraform 2.0"
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

resource "aws_flow_log" "js_vpc_flow_log" {
    vpc_id = aws_vpc.js_vpc.id
    traffic_type = "ALL"
    log_destination_type = "cloud-watch-logs"
    log_destination = aws_cloudwatch_log_group.js_vpc_flow_log_cw_group.arn
    iam_role_arn = aws_iam_role.js_vpc_flow_log_cw_group_role.arn
}


/************************************* Create CloudTrail *************************************/

resource "aws_s3_bucket" "js_cloudtrail_s3_bucket" {
    bucket = "js-cloudtrail-${data.aws_caller_identity.current.account_id}"

    tags = {
        Name        = "js-cloudtrail-s3-bucket"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }

}

resource "aws_s3_bucket_public_access_block" "js_cloudtrail_s3_bucket_block" {
    bucket = aws_s3_bucket.js_cloudtrail_s3_bucket.id

    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "js_cloudtrail_s3_bucket_policy" {
    bucket = aws_s3_bucket.js_cloudtrail_s3_bucket.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "AWSCloudTrailAclCheck"
                Effect = "Allow"
                Principal = {
                    Service = "cloudtrail.amazonaws.com"
                }
                Action = "s3:GetBucketAcl"
                Resource = aws_s3_bucket.js_cloudtrail_s3_bucket.arn
            },
            {
                Sid = "AWSCloudTrailWrite"
                Effect = "Allow"
                Principal = {
                    Service = "cloudtrail.amazonaws.com"
                }
                Action = "s3:PutObject"
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
    name = "/aws/cloudtrail/js-cloudtrail"
    retention_in_days = 7
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

resource "aws_cloudtrail" "js_cloudtrail" {
    name = "js-cloudtrail"
    s3_bucket_name = aws_s3_bucket.js_cloudtrail_s3_bucket.id
    include_global_service_events = true 
    is_multi_region_trail = true 
    enable_log_file_validation = true 

    # cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.js_cloudtrail_cw_logs.arn}"

    cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.js_cloudtrail_cw_logs.arn}:*"
    cloud_watch_logs_role_arn = "${aws_iam_role.js_cloudtrail_cw_role.arn}"

    depends_on = [ 
        aws_s3_bucket_policy.js_cloudtrail_s3_bucket_policy,
        aws_iam_role.js_cloudtrail_cw_role,
        aws_iam_role_policy.js_cloudtrail_cw_role_policy
    ]
}

/************************************* Create ALB Security Group *************************************/

resource "aws_security_group" "js_alb_sg" {
    vpc_id = aws_vpc.js_vpc.id

    tags = {
        Name        = "js-alb-sg"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

resource "aws_vpc_security_group_ingress_rule" "alb_allow_http" {
    security_group_id = aws_security_group.js_alb_sg.id
    cidr_ipv4 = "0.0.0.0/0"
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_allow_all_outbound" {
    security_group_id = aws_security_group.js_alb_sg.id
    cidr_ipv4 = "0.0.0.0/0"
    ip_protocol = "-1"
}



/************************************* Create ALB *************************************/

resource "aws_alb" "js_alb" {
    name = "js-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [
        aws_security_group.js_alb_sg.id
    ]
    subnets = [
        aws_subnet.js_public_subnet_1.id,
        aws_subnet.js_public_subnet_2.id
    ]

    tags = {
        Name        = "js-alb"
        Environment = "dev"
        Project     = "Juice Shop Terraform 2.0"
    }
}

resource "aws_lb_target_group" "js_alb_tg" {
    name = "js-tg"
    port = local.app_host_port
    protocol = "HTTP"
    vpc_id = aws_vpc.js_vpc.id
    target_type = "instance"

    health_check {
      path = "/"
      protocol = "HTTP"
      matcher = "200-399"
      interval = 30
      timeout = 5
      healthy_threshold = 2
      unhealthy_threshold = 2
    }
}

resource "aws_lb_target_group_attachment" "js_alb_tg_attachment_1" {
    target_group_arn = aws_lb_target_group.js_alb_tg.arn
    target_id = aws_instance.js_ubuntu_ec_1.id
    port = local.app_host_port
}

resource "aws_lb_target_group_attachment" "js_alb_tg_attachment_2" {
    target_group_arn = aws_lb_target_group.js_alb_tg.arn
    target_id = aws_instance.js_ubuntu_ec_2.id
    port = local.app_host_port
}

resource "aws_lb_listener" "js_alb_listener" {
    load_balancer_arn = aws_alb.js_alb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.js_alb_tg.arn
    }
}


# resource "aws_network_acl" "js_nacl" {
#     vpc_id = aws_vpc.js_vpc.id

#     tags = {
#         Name        = "js-nacl"
#         Environment = "dev"
#         Project     = "Juice Shop Terraform 2.0"
#     }
# }

# output "alb_dns_name" {
#   value = aws_alb.js_alb.dns_name
# }

/************************************* Create CloudFront *************************************/

resource "aws_wafv2_web_acl" "js_waf" {
    name = "js-waf"
    description = "WAF for Juice Shop CloudFront Dsitribution"
    scope = "CLOUDFRONT"
    default_action {
        allow {}
    }

    rule {
        name = "AWS-CommonRuleSet"
        priority = 1

        override_action {
        #   none {}
            count {}
        }

        statement {
          managed_rule_group_statement {
            name = "AWSManagedRulesCommonRuleSet"
            vendor_name = "AWS"
          }
        }

        visibility_config {
          cloudwatch_metrics_enabled = true
          metric_name = "js-common-rule-set"
          sampled_requests_enabled = true
        }   
    }

    rule {
        name = "RateLimit"
        priority = 2
        action {
            block {}
        }
        statement {
          rate_based_statement {
            limit = 2000
            aggregate_key_type = "IP"
          }
        }

        visibility_config {
          cloudwatch_metrics_enabled = true
          metric_name = "js-rate-limit"
          sampled_requests_enabled = true
        }
    }


    visibility_config {
      cloudwatch_metrics_enabled = true 
      metric_name = "js-waf" 
      sampled_requests_enabled = true 
    }

    tags = {
        Name = "js-waf"
        Environment = "dev"
        Project = "Juice Shop Terraform 2.0"
    }
}

resource "aws_cloudfront_distribution" "js_cdn" {
    enabled = true
    default_root_object = ""

    web_acl_id = aws_wafv2_web_acl.js_waf.arn   # 新加这一行

    origin {
        domain_name = aws_alb.js_alb.dns_name
        origin_id = "js_alb_origin"
        custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "http-only"
            origin_ssl_protocols = ["TLSv1.2"]
        }
    }

    default_cache_behavior {
      allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods = ["GET", "HEAD"]
      target_origin_id = "js_alb_origin"
      viewer_protocol_policy = "redirect-to-https"
      forwarded_values {
        query_string = true
        cookies {
          forward = "all"
        }
      }
      min_ttl = 0
      default_ttl = 0
      max_ttl = 0
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
        Name = "js-cdn"
        Environment = "dev"
        Project = "Juice Shop Terraform 2.0"
    }
}



# output "cloudfront_domain_name" {
#     value = aws_cloudfront_distribution.js_cdn.domain_name
# }
output "deployed_target_app" {
    value = var.target_app
}

output "app_url" {
    description = "Convenience URL for the app that was deployed (accounts for apps not served at root, e.g.AltoroJ)"
    value = "https://${aws_cloudfront_distribution.js_cdn.domain_name}${local.selected_app.health_check_path}"
}




