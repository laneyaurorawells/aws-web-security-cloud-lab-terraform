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

resource "aws_vpc" "js_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "js-vpc"
    Environment = "dev"
    Project     = "Juice Shop Terraform"
  }
}

resource "aws_subnet" "js_public_subnet" {
  vpc_id            = aws_vpc.js_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "js-public-subnet"
    Environment = "dev"
    Project     = "Juice Shop Terraform"
  }
}

resource "aws_internet_gateway" "js_igw" {
  vpc_id = aws_vpc.js_vpc.id

  tags = {
    Name        = "js-igw"
    Environment = "dev"
    Project     = "Juice Shop Terraform"
  }

}

// Create Public Route Table, Any traffic from the public Subnet to the Internet go to Internet Gateway
resource "aws_route_table" "js_public_rt" {
  vpc_id = aws_vpc.js_vpc.id

  tags = {
    Name        = "js-public-rt"
    Environment = "dev"
    Project     = "Juice Shop Terraform"
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
    Project     = "Juice Shop Terraform"
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
              EOF

  tags = {
    Name        = "js-ubuntu-ec"
    Environment = "dev"
    Project     = "Juice Shop Terraform"
  }

}

// Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "js_vpc_flow_logs_group" {

  name = "/aws/js-vpc/js-flow-logs"

  retention_in_days = 7

  tags = {
    Name        = "js-vpc-flow-logs"
    Environment = "dev"
    Project     = "Juice Shop Terraform"
  }
}

// Create Role For VPC Flow Logs to write into CloudWatch Logs
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
}

// Add Role Policy For VPC Flow Logs to write into CloudWatch Logs
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

// Create VPC Flow Logs in VPC
resource "aws_flow_log" "js_vpc_flow_log" {
  vpc_id               = aws_vpc.js_vpc.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.js_vpc_flow_logs_group.arn
  iam_role_arn         = aws_iam_role.js_vpc_flow_log_role.arn
}


/*
  120  aws ec2 describe-flow-logs \\n  --query 'FlowLogs[*].[FlowLogId,FlowLogStatus,LogDestination,DeliverLogsStatus,DeliverLogsErrorMessage]' \\n  --output table
  121  aws ec2 describe-flow-logs \\n  --flow-log-ids fl-0f836c7594dde306f \\n  --query 'FlowLogs[0]' \\n  --output json
  122  aws ec2 describe-vpcs \\n  --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \\n  --output table
  123  for i in {1..50}; do\n  curl -s http://44.204.224.176/ > /dev/null\ndone
  124  terraform state show aws_vpc.js_vpc\n
  125  aws ec2 describe-instances \\n  --query 'Reservations[*].Instances[*].[InstanceId,VpcId,SubnetId,PrivateIpAddress,PublicIpAddress,State.Name]' \\n  --output table
  126  curl -I http://44.204.224.176\n
  127  for i in {1..100}; do\n  curl -s http://44.204.224.176/ > /dev/null\ndone
  128  ssh ubuntu@44.204.224.176
*/