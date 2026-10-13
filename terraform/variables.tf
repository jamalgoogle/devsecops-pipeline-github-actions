variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used as a prefix for resource names"
  type        = string
  default     = "novacart"
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC that will contain the application security group"
  type        = string
}

variable "allowed_cidr" {
  description = "Private CIDR range allowed to reach the application (never 0.0.0.0/0)"
  type        = string
  default     = "10.0.0.0/16"
}
