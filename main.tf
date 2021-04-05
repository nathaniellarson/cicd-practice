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
  required_tags = {
    project     = var.project_name,
    environment = var.environment,
    date = local.date
  }
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

resource "aws_s3_bucket" "cicdaws-bucket" {
  bucket = "awscodepipeline-${local.name_suffix}"
  acl = "private"

  versioning {
    enabled = true
  }

  tags = local.tags
}





# ## Basic Resource
# resource "aws_instance" "cicdaws-simple-pipeline" {
#   ami           = var.amis[var.region]
#   instance_type = "t2.micro"

# }


