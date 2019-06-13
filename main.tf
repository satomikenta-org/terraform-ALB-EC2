provider "aws" {
  region = "${var.aws_region}"
}


# Networking 
module "vpc" {
  source = "github.com/satomikenta-org/terraform-VPC-module.git/vpc"
  AWS_REGION = "${var.aws_region}"
}


# public subnet not in used
resource "aws_subnet" "public_subnet" {
  vpc_id = "${module.vpc.vpc_id}"
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = "true"
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "SUBNET_NEED_FOR_ALB_AT_LEAST_2_AZ"
  }
}

resource "aws_security_group" "api_server" {
  name = "api_server-sg"
  vpc_id = "${module.vpc.vpc_id}"
  
  # for ALB traffic
  ingress = {
    from_port = "${var.app_port}"
    to_port = "${var.app_port}"
    protocol = "tcp"
    security_groups = ["${aws_security_group.alb.id}"]
  }

  # for SSH  * need to specify your ip only in cidr_blocks in prod. 
  ingress = {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress = {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.proj_name}_api_server_sg"
  }
}

resource "aws_security_group" "alb" {
  name = "alb_sg"
  vpc_id = "${module.vpc.vpc_id}"
  ingress = {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress = {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.proj_name}_alb_sg"
  }
}



# EC2  * Need to Provisioning.
resource "aws_instance" "api_server_ec2" {
  ami = "${var.ec2_ami}"
  instance_type = "${var.instance_type}"
  associate_public_ip_address = "true"
  subnet_id = "${module.vpc.public_subnet_id}"
  security_groups = ["${aws_security_group.api_server.id}"]
  key_name = "${var.ec2_key_name}"
  tags = {
    Name = "${var.proj_name}-api_server_ec2"
  }
}



# ALB

resource "aws_alb" "alb" {
  name = "${var.proj_name}-alb"
  subnets = ["${module.vpc.public_subnet_id}", "${aws_subnet.public_subnet.id}"]
  security_groups = ["${aws_security_group.alb.id}"]
  tags = {
    Name = "${var.proj_name}-alb"
  }
}

resource "aws_alb_target_group" "api_servers" {
   name     = "${var.proj_name}-alb-target-group"
   vpc_id = "${module.vpc.vpc_id}"
   target_type = "instance"
   port = "${var.app_port}"
   protocol = "HTTP"
   health_check = {
     path = "${var.health_check_path}"
     interval = 20 # in seconds
     timeout = 10 # in seconds
     healthy_threshold = 3
     unhealthy_threshold = 3
   }
}
resource "aws_lb_target_group_attachment" "api_servers" {
  target_group_arn = "${aws_alb_target_group.api_servers.arn}"
  target_id        = "${aws_instance.api_server_ec2.id}"
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.api_servers.arn}"
  }
}


