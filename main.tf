# Configure the AWS provider
terraform {
  cloud {
    organization = "toantd19_labs"

    workspaces {
      name = "seafile-setup-terraform"
    }
  }
}
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "Terraform"
      Client      = "Tom"
    }
  }
}

variable "bucket_name" {
  type    = string
  default = "toantd19-unique-bucket-tfc-demo"
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = var.bucket_name

  acl    = "private"
  versioning = {
    enabled = true
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "TerraformCloud"
  }
}