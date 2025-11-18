provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_instance" "web" {
  ami           = "ami-0e68e34976bb4db93"
  instance_type = "t3.micro"
}
