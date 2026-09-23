resource "aws_vpc" "js_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "${var.target_app}-vpc"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_subnet" "js_public_subnet_1" {
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.js_vpc.id
  availability_zone = "us-east-1a"

  tags = {
    Name        = "${var.target_app}-public-subnet-1"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_subnet" "js_public_subnet_2" {
  cidr_block        = "10.0.2.0/24"
  vpc_id            = aws_vpc.js_vpc.id
  availability_zone = "us-east-1b"

  tags = {
    Name        = "${var.target_app}-public-subnet-2"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_subnet" "js_private_subnet_1" {
  cidr_block        = "10.0.3.0/24"
  vpc_id            = aws_vpc.js_vpc.id
  availability_zone = "us-east-1a"

  tags = {
    Name        = "${var.target_app}-private-subnet-1"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_subnet" "js_private_subnet_2" {
  cidr_block        = "10.0.4.0/24"
  vpc_id            = aws_vpc.js_vpc.id
  availability_zone = "us-east-1b"

  tags = {
    Name        = "${var.target_app}-private-subnet-2"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

# Add Internet Gateway
resource "aws_internet_gateway" "js-igw" {
  vpc_id = aws_vpc.js_vpc.id

  tags = {
    Name        = "${var.target_app}-igw"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_route_table" "js_public_rt" {
  vpc_id = aws_vpc.js_vpc.id

  tags = {
    Name        = "${var.target_app}-public-rt"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_route" "js_public_rt_route_1" {
  route_table_id         = aws_route_table.js_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.js-igw.id
}

resource "aws_route_table_association" "js_public_rt_association_1" {
  route_table_id = aws_route_table.js_public_rt.id
  subnet_id      = aws_subnet.js_public_subnet_1.id
}

resource "aws_route_table_association" "js_public_rt_association_2" {
  route_table_id = aws_route_table.js_public_rt.id
  subnet_id      = aws_subnet.js_public_subnet_2.id
}

# Add NAT Gateway
resource "aws_eip" "js_nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "js_ngw" {
  allocation_id = aws_eip.js_nat_eip.id
  subnet_id     = aws_subnet.js_public_subnet_1.id

  tags = {
    Name        = "${var.target_app}-ngw"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }

  depends_on = [aws_internet_gateway.js-igw]
}

resource "aws_route_table" "js_private_rt" {
  vpc_id = aws_vpc.js_vpc.id

  tags = {
    Name        = "${var.target_app}-private-rt"
    Environment = "dev"
    Project     = "${var.target_app} Terraform 2.0"
  }
}

resource "aws_route" "js_private_rt_route_1" {
  route_table_id         = aws_route_table.js_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.js_ngw.id
}

resource "aws_route_table_association" "js_private_route_table_association_1" {
  route_table_id = aws_route_table.js_private_rt.id
  subnet_id      = aws_subnet.js_private_subnet_1.id
}

resource "aws_route_table_association" "js_private_route_table_association_2" {
  route_table_id = aws_route_table.js_private_rt.id
  subnet_id      = aws_subnet.js_private_subnet_2.id
}