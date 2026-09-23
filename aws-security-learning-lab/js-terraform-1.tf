/*
resource "aws_instance" "juice_shop" {
  ami           = "ami-0c55b159cbfafe1f0" # 替换为你所在区域的 Ubuntu AMI
  instance_type = "t3.micro"
  
  # 关联你的安全组（确保放行 80 或 3000 端口）
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # 关键：利用 user_data 在启动时运行 Docker
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              # 运行 Juice Shop 并将容器的 3000 端口映射到 EC2 的 80 端口
              docker run -d -p 80:3000 bkimminich/juice-shop
              EOF

  tags = {
    Name = "JuiceShop-Docker"
  }
}
 AWS Cloud (AWS 云端)
 └─ VPC (172.31.0.0/16 - 默认网络隔离圈)
     │
     ├─ Internet Gateway (IGW - 互联网网关，连接外网的桥梁)
     │   ▲
     │   │ 流量通过路由表直达公网子网
     │   ▼
     ├─ Public Subnet (公网子网 - 172.31.1.0/24)
     │   │
     │   └─ 安全组 (Security Group - 虚拟防火墙/保安)
     │       │  入站规则 (Inbound Rules):
     │       │  ── 允许 HTTP (80端口) ──> 任何人 (0.0.0.0/0)
     │       │  ── 允许 SSH  (22端口) ──> 你的个人IP (可选)
     │       │
     │       └─ EC2 实例 (aws_instance - t3.micro)
     │           │  分配有：内网 IP (如 172.31.1.50)
     │           │  绑定有：公网 IP (如 54.x.x.x)
     │           │
     │           └─ 操作系统 (Ubuntu OS)
     │               │ [通过 user_data 脚本自动安装和运行]
     │               ▼
     │            Docker 守护进程 (Docker Daemon)
     │               └─ 容器 (Container): bkimminich/juice-shop
     │                   └─ 应用端口: 3000 <──(映射)──> 主机端口: 80
     │
     └─ Private Subnet (当前方案：未使用/不需要)
*/

/************************************* Create Infrastructure *************************************/
resource "aws_vpc" "js_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "js-vpc"
    Environment = "dev"
    Project     = "Juice Shop Terraform 1.0"
  }
}

resource "aws_subnet" "js_public_subnet" {
  vpc_id            = aws_vpc.js_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "js-public-subnet"
    Environment = "dev"
    Project     = "Juice Shop Terraform 1.0"
  }
}

resource "aws_internet_gateway" "js_igw" {
  vpc_id = aws_vpc.js_vpc.id

  tags = {
    Name        = "js-igw"
    Environment = "dev"
    Project     = "Juice Shop Terraform 1.0"
  }

}

# Create Public Route Table, Any traffic from the public Subnet to the Internet go to Internet Gateway
resource "aws_route_table" "js_public_rt" {
  vpc_id = aws_vpc.js_vpc.id

  tags = {
    Name        = "js-public-rt"
    Environment = "dev"
    Project     = "Juice Shop Terraform 1.0"
  }
}

resource "aws_route" "js_public_rt_route_1" {
  route_table_id         = aws_route_table.js_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.js_igw.id
}

resource "aws_route_table_association" "js_public_rt_association" {
  route_table_id = aws_route_table.js_public_rt.id
  subnet_id      = aws_subnet.js_public_subnet.id
}

resource "aws_security_group" "js_sg" {
  vpc_id      = aws_vpc.js_vpc.id
  name        = "js-sg"
  description = "Security Group for public subnet"

  tags = {
    Name        = "js-web-sg"
    Project     = "Juice Shop Terraform 1.0"
    Environment = "dev"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-ssh" {
  security_group_id = aws_security_group.js_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow-http" {
  security_group_id = aws_security_group.js_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.js_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}


/************************************* Create CloudWatch Agent on EC2 Instance *************************************/

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cwagent_role" {
  name = "js-cwagent-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cwagent_server_policy" {
  role = aws_iam_role.cwagent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cwagent_profile" {
  name = "js-cwagent-profile"
  role = aws_iam_role.cwagent_role.name
}


/************************************* Create EC2 Instance *************************************/

data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "js_ubuntu_ec" {
  ami           = data.aws_ssm_parameter.amazon_linux.value
  instance_type = "t2.micro"
  vpc_security_group_ids = [
    aws_security_group.js_sg.id
  ]

  subnet_id = aws_subnet.js_public_subnet.id

  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.cwagent_profile.name

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              
              # Pull and run OWASP Juice Shop
              docker pull bkimminich/juice-shop
              docker run -d \
                --name juice-shop \
                -p 80:3000 \
               bkimminich/juice-shop

              wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

              dpkg -i -E amazon-cloudwatch-agent.deb

              cat << 'CFG' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "metrics": {
                  "namespace":"CWAgent",
                  "metrics_collected": {
                    "mem":{"measurement":["mem_used_percent"]},
                    "disk":{"measurement":["used_percent"],
                            "resources":["/"]}
                  }
                }
              }
              CFG

              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config -m ec2 -s \
                -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              EOF

  tags = {
    Name        = "js-ubuntu-ec"
    Environment = "dev"
    Project     = "Juice Shop Terraform 1.0"
  }

}



/************************************* Create VPC Flow Logs *************************************/

# Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "js_vpc_flow_logs_group" {

  name = "/aws/js-vpc/js-flow-logs"

  retention_in_days = 7

  tags = {
    Name        = "js-vpc-flow-logs"
    Environment = "dev"
    Project     = "Juice Shop Terraform 1.0"
  }
}

# Create Role For VPC Flow Logs to write into CloudWatch Logs
resource "aws_iam_role" "js_vpc_flow_log_role" {
  name = "js-vpc-flow-log-role"

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
    Name        = "js-vpc-flow-log-role"
    Environment = "dev"
    Project     = "Juice Shop Terraform 1.0"
  }
}

# Add Role Policy For VPC Flow Logs to write into CloudWatch Logs
resource "aws_iam_role_policy" "js_vpc_flow_log_policy" {
  name = "js-vpc-flow-log-policy"
  role = aws_iam_role.js_vpc_flow_log_role.id

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

        # Resource = "${aws_cloudwatch_log_group.js_vpc_flow_logs_group.arn}"
        Resource = "*"

      }
    ]
  })

}

# Create VPC Flow Logs in VPC
resource "aws_flow_log" "js_vpc_flow_log" {
  vpc_id               = aws_vpc.js_vpc.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.js_vpc_flow_logs_group.arn
  iam_role_arn         = aws_iam_role.js_vpc_flow_log_role.arn
}

data "aws_caller_identity" "current" {}


/************************************* Create CloudTrail *************************************/

# Create S3 bucket for cloudtrail
resource "aws_s3_bucket" "js_cloudtrail_s3_bucket" {
  bucket = "js-security-cloudtrail-081535519482"

  tags = {
    Name        = "js-cloudtrail-s3-bucket"
    Environment = "dev"
    Project     = "Juice Shop Terraform 1.0"
  }
}


# Create public access block for cloudtrail s3 bucket 
resource "aws_s3_bucket_public_access_block" "js_cloudtrail_s3_bucket_block" {
  bucket = aws_s3_bucket.js_cloudtrail_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create bucket policy for the cloudtrail s3 bucket
resource "aws_s3_bucket_policy" "js_cloudtrail_bucket_policy" {
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

# Create CloudWatch Log Group for S3 Bucket
resource "aws_cloudwatch_log_group" "js_cloudtrail_logs" {
  name              = "/aws/cloudtrail/js-cloudtrail"
  retention_in_days = 7
}

# Create IAM Role for Cloudtrail to write into cloudwatch log group 
resource "aws_iam_role" "js_cloudtrail_cloudwatch_role" {
  name = "js-cloudtrail-cloudwatch-role"
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

# Then give permission to the IAM role for cloudtrail to write into cloudwatch log group
resource "aws_iam_role_policy" "js_cloudtrail_cloudwatch_policy" {
  role = aws_iam_role.js_cloudtrail_cloudwatch_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.js_cloudtrail_logs.arn}:*"
    }]
  })
}

# Create Cloudtrail
resource "aws_cloudtrail" "js_cloudtrail" {
  name                          = "js-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.js_cloudtrail_s3_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.js_cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.js_cloudtrail_cloudwatch_role.arn

  depends_on = [
    aws_s3_bucket_policy.js_cloudtrail_bucket_policy,
    aws_iam_role_policy.js_cloudtrail_cloudwatch_policy,
  ]
}



/************************************* Create AWS Config *************************************/

# Create S3 Bucket for AWS Config
resource "aws_s3_bucket" "js_config_bucket" {
  bucket = "js-security-config-d81535519482"

  tags = {
    Name = "js-config-bucket"
    Environment = "dev"
    Project = "Juice Shop Terraform"
  }
}

# Add Public Access Block to S3 Bucket
resource "aws_s3_bucket_public_access_block" "js_config_bucket_block" {
  bucket = aws_s3_bucket.js_config_bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Create bucket policy
resource "aws_s3_bucket_policy" "js_config_bucket_policy" {
  bucket = aws_s3_bucket.js_config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AWSConfigBucketPermissionCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "s3:GetBucketAcl"
        Resource = "${aws_s3_bucket.js_config_bucket.arn}"
      },
      {
        Sid = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.js_config_bucket.arn}/*"
        Condition = {
          StringEquals = {"s3:x-amz-acl" = "bucket-owner-full-control"}
        }
      }
    ]
  })
}

# Create IAM Role for AWS Config to read and record configuration of various kinds of AWS services
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
    Name = "js-config-role"
    Environment = "dev"
    Project = "Juice Shop Terraform"
  }
}

# Attach permission to the IAM role created above
resource "aws_iam_role_policy_attachment" "js_config_role_policy" {
  role = aws_iam_role.js_config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Create Configuration Recorder
resource "aws_config_configuration_recorder" "js_recorder" {
  name = "js-config_recorder"
  role_arn = aws_iam_role.js_config_role.arn

  recording_group {
    all_supported = true
    include_global_resource_types = true
  }
}


# Create Delivery Channel 
resource "aws_config_delivery_channel" "js_delivery_channel" {
  name = "js-config-delivery-channel"
  s3_bucket_name = aws_s3_bucket.js_config_bucket.bucket
  depends_on = [ aws_config_configuration_recorder.js_recorder ]
}

# Start Recorder
resource "aws_config_configuration_recorder_status" "js_recorder_status" {
  name = aws_config_configuration_recorder.js_recorder.name
  is_enabled = true
  depends_on = [ aws_config_delivery_channel.js_delivery_channel ]
}