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

// an AWS subnet is only considered "public" when its route table contains a route that directs internet-bound traffic to an Internet Gateway (IGW)

// to allow internet access to our subnet we need an internet gateway

resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/27"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.32/27"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}

// route tables -> 

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "rt_associate_public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
}

// nat gateway -> the private instance is able to reach out to the internet and without an internet gateway no one outside the vpc can reach the instance
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet.id # NAT Gateway must be in a public subnet
  tags = {
    Name = "main-nat-gateway"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gateway.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

// security group -> like a virtual firewall. controlls incoming and outcoming traffic

resource "aws_security_group" "public_security_group" {
  name        = "ec2-securitygroup-public"
  description = "Ingress SSH and Egress to anywhere"
  vpc_id      = aws_vpc.my_vpc.id

  //  ingress {
  //    from_port   = 80
  //    to_port     = 80
  //    protocol    = "tcp"
  //    cidr_blocks = ["0.0.0.0/0"]
  //  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_security_group" {
  name        = "ec2-securitygroup-private"
  description = "Ingress SSH and Egress to anywhere "
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// to generate a new ssh key run: `ssh-keygen -t rsa -b 2048 -f ~/.ssh/my-ec2-key`

resource "aws_key_pair" "keypair" {
  key_name   = "terraform-keypair"
  public_key = file("~/.ssh/my-ec2-key.pub")
}

resource "aws_instance" "public_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  key_name                    = aws_key_pair.keypair.key_name
  vpc_security_group_ids      = [aws_security_group.public_security_group.id]
  associate_public_ip_address = true

  tags = {
    Name = "my-ec2-instance"
  }
}

resource "aws_instance" "private_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.private_subnet.id
  key_name                    = aws_key_pair.keypair.key_name
  vpc_security_group_ids      = [aws_security_group.private_security_group.id]
  associate_public_ip_address = false

  tags = {
    Name = "my-second-ec2-instance"
  }
}


// to ssh into the instance after it is launched, run: `ssh -i ~/.ssh/my-ec2-key ubuntu@INSTANCE_PUBLIC_IP_ADDRESS`


