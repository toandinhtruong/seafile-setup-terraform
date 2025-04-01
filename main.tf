# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Use the default VPC
data "aws_vpc" "default" {
  default = true
}

# Use a subnet from the default VPC
data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for EC2 instance
resource "aws_security_group" "seafile_sg" {
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.sg_cidr
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "seafile-sg"
  }
}
# IAM Role for EC2 to access S3 and SSM
resource "aws_iam_role" "seafile_ssm_role" {
  name = "seafile-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for SSM access
resource "aws_iam_policy" "seafile_ssm_policy" {
  name = "seafile-ssm-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:SendCommand",
          "ssm:GetConnectionStatus",
          "ssm:DescribeSessions",
          "ssm:TerminateSession"
        ]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.seafile_server.id}",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetInventory"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "seafile_ssm_attach" {
  role       = aws_iam_role.seafile_ssm_role.name
  policy_arn = aws_iam_policy.seafile_ssm_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "seafile_profile" {
  name = "seafile-ec2-profile"
  role = aws_iam_role.seafile_ssm_role.name
}

# EC2 Instance for Seafile
resource "aws_instance" "seafile_server" {
  ami                    = "ami-02f624c08a83ca16f" # Amazon Linux 2 AMI (us-east-1, update for your region)
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default_subnets.ids[0]
  vpc_security_group_ids = [aws_security_group.seafile_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.seafile_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              sudo amazon-linux-extras install docker -y
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              mkdir -p ~/.docker/cli-plugins/
              curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
              chmod +x ~/.docker/cli-plugins/docker-compose
              mkdir /opt/seafile
              cd /opt/seafile
              wget -O "docker-compose.yml" "https://manual.seafile.com/11.0/docker/docker-compose/ce/11.0/docker-compose.yml"
              docker compose up -d
              EOF

  tags = {
    Name = "seafile-server"
    SSM  = "enabled"
  }
}

# Outputs
output "seafile_server_ip" {
  value = aws_instance.seafile_server.public_ip
}

output "seafile_server_id" {
  value = aws_instance.seafile_server.id
}
