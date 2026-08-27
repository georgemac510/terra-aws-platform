terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# NETWORK
#
# The Docker network became a VPC. One PUBLIC subnet only, deliberately: a
# private subnet needs a NAT gateway to reach the internet, and that bills
# ~$33/month from the moment it exists whether you use it or not.
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# SECURITY GROUP - the cloud equivalent of "don't publish 5432".
#
# Port 80 is open to the world. SSH is restricted to YOUR address. Postgres
# and the api are not here at all: they stay on the Docker network inside the
# instance, unreachable from outside.
# ---------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.project}-sg"
  description = "Web from anywhere, SSH from one address"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from operator only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    description = "All outbound - needed for apt, git clone, docker pull"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg" }
}

# ---------------------------------------------------------------------------
# INSTANCE
# ---------------------------------------------------------------------------

# A data source READS something AWS already has. It is not created or
# destroyed by Terraform. Note most_recent = true means this can silently
# resolve to a new AMI later and force the instance to be replaced; real
# teams pin the AMI id for exactly that reason.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "operator" {
  key_name   = "${var.project}-key"
  public_key = file(var.public_key_path)
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.operator.key_name

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Runs once, on first boot only. Changing it replaces the instance.
  user_data = templatefile("${path.module}/user_data.sh", {
    repo_url    = var.repo_url
    db_password = var.db_password
    project     = var.project
  })

  tags = { Name = "${var.project}-app" }
}
