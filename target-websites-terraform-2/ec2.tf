/************************************* Create EC2 *************************************/

data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "js_ubuntu_ec_1" {
  ami           = data.aws_ssm_parameter.amazon_linux.value
  instance_type = local.selected_app.instance_type
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
    Project     = "${var.target_app} Terraform 2.0"
  }

  # depends_on = [ aws_nat_gateway.js_ngw ]
  depends_on = [time_sleep.wait_for_nat]

}


resource "aws_instance" "js_ubuntu_ec_2" {
  ami           = data.aws_ssm_parameter.amazon_linux.value
  instance_type = local.selected_app.instance_type
  vpc_security_group_ids = [
    aws_security_group.js_sg.id
  ]

  subnet_id = aws_subnet.js_private_subnet_2.id

  iam_instance_profile = aws_iam_instance_profile.js_ec2_ssm_profile.name

  user_data = local.user_data_rendered

  tags = {
    Name        = "${var.target_app}-ec-2"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }

  # depends_on = [ aws_nat_gateway.js_ngw ]
  depends_on = [time_sleep.wait_for_nat]

}

resource "time_sleep" "wait_for_nat" {
  depends_on      = [aws_nat_gateway.js_ngw]
  create_duration = "60s"
}