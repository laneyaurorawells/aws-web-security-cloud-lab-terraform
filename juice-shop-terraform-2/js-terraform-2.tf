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
    from_port = 80
    to_port = 80
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

user_data = <<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

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
    Name        = "js-ubuntu-ec-1"
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

user_data = <<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

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
    Name        = "js-ubuntu-ec-2"
    Environment = "dev"
    Project     = "Juice Shop Terraform 2.0"
  }
 
    depends_on = [ aws_nat_gateway.js_ngw ]
  
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
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.js_vpc.id
    target_type = "instance"

    health_check {
      path = "/"
      protocol = "HTTP"
      matcher = "200"
      interval = 30
      timeout = 5
      healthy_threshold = 2
      unhealthy_threshold = 2
    }
}

resource "aws_lb_target_group_attachment" "js_alb_tg_attachment_1" {
    target_group_arn = aws_lb_target_group.js_alb_tg.arn
    target_id = aws_instance.js_ubuntu_ec_1.id
    port = 80
}

resource "aws_lb_target_group_attachment" "js_alb_tg_attachment_2" {
    target_group_arn = aws_lb_target_group.js_alb_tg.arn
    target_id = aws_instance.js_ubuntu_ec_2.id
    port = 80
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

output "alb_dns_name" {
  value = aws_alb.js_alb.dns_name
}