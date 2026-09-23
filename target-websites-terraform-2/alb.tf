/************************************* Create ALB *************************************/

resource "aws_alb" "js_alb" {
  name               = "js-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.js_alb_sg.id
  ]
  subnets = [
    aws_subnet.js_public_subnet_1.id,
    aws_subnet.js_public_subnet_2.id
  ]

  tags = {
    Name        = "${var.target_app}-alb"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_lb_target_group" "js_alb_tg" {
  name        = "js-tg"
  port        = local.selected_app.host_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.js_vpc.id
  target_type = "instance"

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }
  
  health_check {
    path                = local.selected_app.health_check_path
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "js_alb_tg_attachment_1" {
  target_group_arn = aws_lb_target_group.js_alb_tg.arn
  target_id        = aws_instance.js_ubuntu_ec_1.id
  port             = local.selected_app.host_port
}

resource "aws_lb_target_group_attachment" "js_alb_tg_attachment_2" {
  target_group_arn = aws_lb_target_group.js_alb_tg.arn
  target_id        = aws_instance.js_ubuntu_ec_2.id
  port             = local.selected_app.host_port
}

resource "aws_lb_listener" "js_alb_listener" {
  load_balancer_arn = aws_alb.js_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.js_alb_tg.arn
  }
}