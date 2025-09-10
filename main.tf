â# Provider設定
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 使用可能なAZを取得
data "aws_availability_zones" "available" {
  state = "available"
}

# 出力値
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "ec2_public_1_public_ip" {
  description = "Public IP of EC2 instance in public subnet 1"
  value       = aws_instance.public_1.public_ip
}

output "ec2_public_2_public_ip" {
  description = "Public IP of EC2 instance in public subnet 2"
  value       = aws_instance.public_2.public_ip
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}
