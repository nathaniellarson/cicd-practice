variable "region" {
  default = "us-east-1"
}

variable "access_key" {
  default = ""
}

variable "secret_key" {
  default = ""
}

variable "amis" {
  type = map(string)
  default = {
    "us-east-1" = "ami-0915bcb5fa77e4892" 
    "us-west-2" = "ami-fc0b939c"
  }
}

variable project_name {
  description = "CI/CD template project name"
  default = "cicdaws"
}

variable environment {
  default = "dev"
}

variable "timestamp" {
  default = "no-timestamp"
}

variable "date" {
  default = "no-date"
}

variable "resource_tags" {
  type = map(string)
  default = {
    project = "cicdaws"
    environment = "dev"
    date = "nodate"
  }
}