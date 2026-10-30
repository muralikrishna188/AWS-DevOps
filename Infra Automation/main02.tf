terraform {
  backend "s3" {
  bucket = "irtct-devstg-000198"  
  key    = "testfolder/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true
    
  }  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.70.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}

resource "aws_vpc" "awsvpc01" {
  cidr_block           = "10.86.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "awsintgtw01" {
  vpc_id = aws_vpc.awsvpc01.id
}

resource "aws_subnet" "awswebsubnet01" {
  vpc_id                  = aws_vpc.awsvpc01.id
  cidr_block              = "10.86.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "awspublicroute" {
  vpc_id = aws_vpc.awsvpc01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.awsintgtw01.id
  }
}

resource "aws_route_table_association" "web" {
  subnet_id      = aws_subnet.awswebsubnet01.id
  route_table_id = aws_route_table.awspublicroute.id
}

resource "aws_security_group" "awswebsg" {
  name   = "websg"
  vpc_id = aws_vpc.awsvpc01.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "awswebsrvr" {
  ami                    = "ami-02a9cdd4e98bc3c78"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.awswebsubnet01.id
  vpc_security_group_ids = [aws_security_group.awswebsg.id]
}