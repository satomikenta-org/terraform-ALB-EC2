variable "proj_name" {}
variable "aws_region" {
  description = " Tokyo => 'ap-northeast-1' "
}

variable "app_port" {
  description = "application port listening in ec2 instance."
}

variable "ec2_key_name" {
  description = "You Need To Create EC2 Key_Pare first."
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ec2_ami" {
  default = "ami-0ebbf2179e615c338" # amazon_linux
}

variable "health_check_path" {
  default = "/"
}

