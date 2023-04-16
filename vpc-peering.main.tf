## Local Variables

locals {
  cidr  = "172.16.0.0/26"
  env   = "jlong-vpc-peering"
  my_ip = "[REDACTED]/32"
}

## Outputs

output "vpc1_instance" {
  value = {
    public_ip  = aws_instance.vpc1.public_ip
    private_ip = aws_instance.vpc1.private_ip
  }
}

output "vpc2_instance" {
  value = {
    public_ip  = aws_instance.vpc2.public_ip
    private_ip = aws_instance.vpc2.private_ip
  }
}

## Providers

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-2" # Ohio
  default_tags {
    tags = {
      Environment = local.env
    }
  }
}

## Data

data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }
}

## "Global"

resource "aws_key_pair" "keypair" {
  key_name   = "keypair"
  public_key = file("~/.ssh/id_rsa.pub")
}

## VPC1

resource "aws_vpc" "vpc1" {
  cidr_block = cidrsubnet(local.cidr, 1, 0)

  tags = {
    Name = "${local.env}-vpc1"
  }
}

resource "aws_internet_gateway" "vpc1" {
  vpc_id = aws_vpc.vpc1.id
}

resource "aws_route" "vpc1_internet_gateway" {
  route_table_id         = aws_vpc.vpc1.main_route_table_id
  gateway_id             = aws_internet_gateway.vpc1.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "vpc1_peering_connection" {
  route_table_id            = aws_vpc.vpc1.main_route_table_id
  destination_cidr_block    = cidrsubnet(local.cidr, 1, 1)
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc1_vpc2.id
}

resource "aws_security_group" "vpc1" {
  name   = "vpc1"
  vpc_id = aws_vpc.vpc1.id
}

resource "aws_security_group_rule" "vpc1_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.cidr, local.my_ip]
  security_group_id = aws_security_group.vpc1.id
}

resource "aws_security_group_rule" "vpc1_egress" {
  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.cidr]
  security_group_id = aws_security_group.vpc1.id
}

resource "aws_subnet" "vpc1" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = cidrsubnet(aws_vpc.vpc1.cidr_block, 1, 0)

  tags = {
    Name = "${local.env}-vpc1"
  }
}

resource "aws_instance" "vpc1" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.vpc1.id
  key_name                    = aws_key_pair.keypair.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.vpc1.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
}

## VPC2

resource "aws_vpc" "vpc2" {
  cidr_block = cidrsubnet(local.cidr, 1, 1)

  tags = {
    Name = "${local.env}-vpc2"
  }
}

resource "aws_internet_gateway" "vpc2" {
  vpc_id = aws_vpc.vpc2.id
}

resource "aws_route" "vpc2_internet_gateway" {
  route_table_id         = aws_vpc.vpc2.main_route_table_id
  gateway_id             = aws_internet_gateway.vpc2.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "vpc2_peering_connection" {
  route_table_id            = aws_vpc.vpc2.main_route_table_id
  destination_cidr_block    = cidrsubnet(local.cidr, 1, 0)
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc1_vpc2.id
}

resource "aws_security_group" "vpc2" {
  name   = "vpc2"
  vpc_id = aws_vpc.vpc2.id
}

resource "aws_security_group_rule" "vpc2_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.cidr, local.my_ip]
  security_group_id = aws_security_group.vpc2.id
}

resource "aws_security_group_rule" "vpc2_egress" {
  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.cidr]
  security_group_id = aws_security_group.vpc2.id
}

resource "aws_subnet" "vpc2" {
  vpc_id     = aws_vpc.vpc2.id
  cidr_block = cidrsubnet(aws_vpc.vpc2.cidr_block, 1, 0)

  tags = {
    Name = "${local.env}-vpc2"
  }
}

resource "aws_instance" "vpc2" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.vpc2.id
  key_name                    = aws_key_pair.keypair.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.vpc2.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
}


## VPC peering connection
resource "aws_vpc_peering_connection" "vpc1_vpc2" {
  vpc_id        = aws_vpc.vpc1.id
  peer_vpc_id   = aws_vpc.vpc2.id
  peer_owner_id = data.aws_caller_identity.current.account_id
  auto_accept   = true
}

