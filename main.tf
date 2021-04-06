## Required header
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

locals {
  timestamp = timestamp()
  date = formatdate("YYYYMMDD", local.timestamp)
  ec2_name = "MyCodePipelineDemo"
  required_tags = {
    project     = var.project_name,
    environment = var.environment,
    date = local.date
  }
  ec2_tags = merge(required_tags, {"Name": local.ec2_name})
  tags = merge(var.resource_tags, local.required_tags) # LATER takes precendence, i.e. local.required_tags will overwrite
  name_suffix = "${var.project_name}-${var.environment}-${local.date}"
}

## Option 1: Use named profile (e.g. "academy")
provider "aws" {
  profile = "academy"
  region  = var.region
}
## OR
## Option 2: Use access key and secret access key
# provider "aws" {
#   access_key = var.access_key 
#   secret_key = var.secret_key
#   region     = var.region
# }

## RESOURCES
## In the order of creation in the tutorial:
## https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-simple-s3.html

## Step 1
resource "aws_s3_bucket" "cicdaws-bucket" {
  bucket = "awscodepipeline-${local.name_suffix}"
  acl = "private"

  versioning {
    enabled = true
  }

  tags = local.tags
}

## Step 2 (with Linux): Launch EC2 Instances

# IAM Role
resource "aws_iam_role" "cicdaws-ec2-role" {
  name = "EC2InstanceRole"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({ # this is what allows certain EC2 instances to assume this role
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

# Managed AWS policies
data "aws_iam_policy" "AmazonEC2RoleforAWSCodeDeploy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# Attachments -- this gives the role permission to do things
resource "aws_iam_role_policy_attachment" "AmazonEC2RoleforAWSCodeDeploy-attach" {
  role       = aws_iam_role.cicdaws-ec2-role.name
  policy_arn = data.aws_iam_policy.AmazonEC2RoleforAWSCodeDeploy.arn
}

# Instance Role -- this profile is needed to associate with the EC2 instance
resource "aws_iam_instance_profile" "cicdaws-ec2-instance-role" {
  name = "EC2InstanceRoleProfile"
  role = aws_iam_role.cicdaws-ec2-role.name
}

# Key Pair
resource "aws_key_pair" "awscicd-key-pair" {
  key_name   = "EC2InstanceKeyPair"
  public_key = file("EC2InstanceKeyPair.pub")
  tags = local.tags
}

# AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group
resource "aws_security_group" "cicdaws-sg" {
  name = "allow-my-ip-security-group"
  description = "The security group for the EC2 instances, which allows only access from this IP address"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp" # use "tcp" instead of "ssh" or what I think of as the protocol
    cidr_blocks = ["98.249.11.45/32"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["98.249.11.45/32"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["98.249.11.45/32"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}

# Instances
resource "aws_instance" "cicdaws-ec2-instances" {
  ami = data.aws_ami.amazon_linux.id # interesting method to grab the latest AMI
  instance_type = "t2.micro"
  count = 2
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.cicdaws-ec2-instance-role.name
  user_data = <<EOF
    #!/bin/bash
    yum -y update
    yum install -y ruby
    yum install -y aws-cli
    cd /home/ec2-user
    aws s3 cp s3://aws-codedeploy-${var.region}/latest/install . --region ${var.region}
    chmod +x ./install
    ./install auto
    EOF
  key_name = aws_key_pair.awscicd-key-pair.key_name
  security_groups = ["${aws_security_group.cicdaws-sg.name}"]
  tags = local.ec2_tags
}

## Step 3: CodeDeploy Application

# Application
resource "aws_codedeploy_app" "cicdaws-codedeploy-app" {
  compute_platform = "Server"
  name             = "MyDemoApplication"
}

# Deployment Group Service Role
# IAM Role
resource "aws_iam_role" "cicdaws-codedeploy-role" {
  name = "AWSCodeDeployRole"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole"
        "Sid": "",
        "Effect": "Allow",
        "Principal": {
          "Service": "codedeploy.amazonaws.com"
        },
      }
    ]
  })

  tags = local.tags
}

# Managed AWS policies
data "aws_iam_policy" "AWSCodeDeployRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# Attachments -- this gives the role permission to do things
resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole-attach" {
  role       = aws_iam_role.cicdaws-codedeploy-role.name
  policy_arn = data.aws_iam_policy.AWSCodeDeployRole.arn
}

# Deployment Group
resource "aws_codedeploy_deployment_group" "cicdaws-codedeploy-dev-group" {
  app_name              = aws_codedeploy_app.cicdaws-codedeploy-app.name
  deployment_group_name = "MyDemoDeploymentGroup"
  service_role_arn      = aws_iam_role.cicdaws-codedeploy-role.arn

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = local.ec2_name
    }
  }

  #Optional
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  
  deployment_style {
    deployment_type = "IN_PLACE"
  }
}




