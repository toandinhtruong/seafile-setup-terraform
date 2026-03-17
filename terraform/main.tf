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
  region = "us-east-1"
}

# -----------------------
# Default VPC
# -----------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -----------------------
# ECR
# -----------------------
resource "aws_ecr_repository" "repo" {
  name = "demo-java-app"
}

# -----------------------
# ECS Cluster
# -----------------------
resource "aws_ecs_cluster" "cluster" {
  name = "demo-cluster"
}

# -----------------------
# AMI (FIXED x86_64)
# -----------------------
data "aws_ami" "ecs" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# -----------------------
# Launch Template
# -----------------------
resource "aws_launch_template" "lt" {
  name_prefix   = "ecs-demo"
  image_id      = data.aws_ami.ecs.id
  instance_type = "t3.micro"

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config
EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "demo"
    }
  }
}

# -----------------------
# AutoScaling Group
# -----------------------
resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = data.aws_subnets.default.ids

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
}

# -----------------------
# ECS Task Definition
# -----------------------
resource "aws_ecs_task_definition" "task" {
  family                   = "demo-task"
  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${aws_ecr_repository.repo.repository_url}:latest"
      cpu   = 256
      memory = 512
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])
}

# -----------------------
# ECS Service (NO CodeDeploy)
# -----------------------
resource "aws_ecs_service" "service" {
  name            = "demo-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
}

# -----------------------
# IAM Roles
# -----------------------
resource "aws_iam_role" "codebuild" {
  name = "demo-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role" "codedeploy" {
  name = "demo-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cd_ec2" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# -----------------------
# CodeDeploy EC2 ONLY
# -----------------------
resource "aws_codedeploy_app" "ec2" {
  name             = "ec2-app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "ec2" {
  app_name              = aws_codedeploy_app.ec2.name
  deployment_group_name = "ec2-dg"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      value = "demo"
      type  = "KEY_AND_VALUE"
    }
  }
}

# -----------------------
# CodeBuild
# -----------------------
resource "aws_codebuild_project" "build" {
  name         = "demo-build"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "REPO_URI"
      value = aws_ecr_repository.repo.repository_url
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yaml"
  }
}

# -----------------------
# S3 for Pipeline
# -----------------------
resource "aws_s3_bucket" "bucket" {
  bucket = "demo-pipeline-${random_id.id.hex}"
}

resource "random_id" "id" {
  byte_length = 4
}

# -----------------------
# CodePipeline Role
# -----------------------
resource "aws_iam_role" "pipeline" {
  name = "demo-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# -----------------------
# CodePipeline
# -----------------------
resource "aws_codepipeline" "pipeline" {
  name     = "demo-pipeline"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      provider         = "GitHub"
      owner            = "ThirdParty"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        Owner      = "<github-user>"
        Repo       = "<repo>"
        Branch     = "main"
        OAuthToken = "<token>"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      provider         = "CodeBuild"
      owner            = "AWS"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["build"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy-EC2"
      category        = "Deploy"
      provider        = "CodeDeploy"
      owner           = "AWS"
      version         = "1"
      input_artifacts = ["build"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.ec2.name
        DeploymentGroupName = aws_codedeploy_deployment_group.ec2.deployment_group_name
      }
    }
  }
}