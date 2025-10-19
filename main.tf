terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  profile = "study"
  region  = "us-east-1"
}



// VPC: Virtual Private Network -> a fence around a bunch of resources, it separates resources from other VPCs.

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/26"

  tags = {
    Name = "new-vpc"
  }
}

// subnet -> subdivions of the ip ranges -> a postal code
// it is necessary to have a subnet to launch resources in a vpc

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/27"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-sunet"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.32/27"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-sunet"
  }
}
// security group -> like a virtual firewall



// route tables -> 
// to allow internet acess to our subnet we need an internet gateway

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type
  subnet_id     = aws_subnet.private_subnet.id

  tags = {
    Name = var.instance_name
  }
}
