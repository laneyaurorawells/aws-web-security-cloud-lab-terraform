/************************************* Create VPC Flow Logs *************************************/

resource "aws_cloudwatch_log_group" "js_vpc_flow_log_cw_group" {
  name              = "/aws/js-vpc/js-flow-logs"
  retention_in_days = 7

  tags = {
    Name        = "${var.target_app}-vpc-flow-logs"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}


resource "aws_flow_log" "js_vpc_flow_log" {
  vpc_id               = aws_vpc.js_vpc.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.js_vpc_flow_log_cw_group.arn
  iam_role_arn         = aws_iam_role.js_vpc_flow_log_cw_group_role.arn
}