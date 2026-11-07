data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "image-id"
    values = ["ami-0dd60a46ecc6eac16"]
  }
}

# VPC

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

# PUBLIC SUBNET

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# INTERNET GATEWAY

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# PUBLIC ROUTE TABLE

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# ROUTE TABLE ASSOCIATION

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# IAM ROLE FOR EC2 SSM

resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-ssm-role"
  }
}

# ATTACH SSM POLICY

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM INSTANCE PROFILE

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# EC2 INSTANCE

resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    # Update packages
    apt-get update -y

    # Install Docker, Git and Snap
    apt-get install -y docker.io git snapd

    # Start Docker
    systemctl enable --now docker

    # Add Ubuntu user to Docker group
    usermod -aG docker ubuntu

    # Install SSM Agent if missing
    if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
      snap install amazon-ssm-agent --classic
    fi

    # Start SSM Agent
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service

    # Verify installations
    docker --version
    git --version
  EOF

  user_data_replace_on_change = true

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}