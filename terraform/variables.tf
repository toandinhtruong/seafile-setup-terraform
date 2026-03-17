variable "aws_region" {
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "sg_cidr" {
  description = "CIDR blocks for security group access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}

