/************************************* Create EC2 Security Group*************************************/
resource "aws_security_group" "js_sg" {
  vpc_id = aws_vpc.js_vpc.id

  tags = {
    Name        = "${var.target_app}-sg"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_allow_alb_sg_only" {
  security_group_id            = aws_security_group.js_sg.id
  referenced_security_group_id = aws_security_group.js_alb_sg.id
  from_port                    = local.selected_app.host_port
  to_port                      = local.selected_app.host_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_allow_all_outbound" {
  security_group_id = aws_security_group.js_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


/************************************* Create ALB Security Group *************************************/

resource "aws_security_group" "js_alb_sg" {
  vpc_id = aws_vpc.js_vpc.id

  tags = {
    Name        = "${var.target_app}-alb-sg"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_allow_http" {
  security_group_id = aws_security_group.js_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_allow_all_outbound" {
  security_group_id = aws_security_group.js_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}