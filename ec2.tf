# 最新のAmazon Linux 2023 AMIを取得
data "aws_ami" "amazon_linux2023" {
  most_recent = true
  owners      = ["137112412989"] 
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2用セキュリティグループ
resource "aws_security_group" "ec2_sg" {
  name        = "hcp-terraform-handson-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "${var.project_name}-ec2-sg"
  }
}

# Nginx起動用userdata script
locals {
  nginx_userdata_1 = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
    sed -i 's/x!/x!-01/g' /usr/share/nginx/html/index.html
  EOF

  nginx_userdata_2 = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
    sed -i 's/x!/x!-02/g' /usr/share/nginx/html/index.html
  EOF
}

# EC2インスタンス - パブリックサブネット1
resource "aws_instance" "public_1" {
  ami                    = data.aws_ami.amazon_linux2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data              = base64encode(local.nginx_userdata_1)

  tags = {
    Name = "${var.project_name}-ec2-public-1"
  }
}

# EC2インスタンス - パブリックサブネット2
resource "aws_instance" "public_2" {
  ami                    = data.aws_ami.amazon_linux2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data              = base64encode(local.nginx_userdata_2)

  tags = {
    Name = "${var.project_name}-ec2-public-2"
  }
}

# ALB用セキュリティグループ
resource "aws_security_group" "alb_sg" {
  name        = "hcp-terraform-handson-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "${var.project_name}-alb-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# ターゲットグループ
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# ターゲットグループにEC2インスタンスを登録
resource "aws_lb_target_group_attachment" "public_1" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.public_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "public_2" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.public_2.id
  port             = 80
}

# ALBリスナー
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
