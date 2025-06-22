provider "aws" {
    region = "eu-north-1"

}
data "aws_availability_zones" "available" {
    state = "available"
}

#vpc
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
}

#subnets
resource "aws_subnet" "public" {
 count = 2
 vpc_id = aws_vpc.main.id
 cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
 map_public_ip_on_launch = true
 availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_subnet" "private" {
    count = 2
    vpc_id = aws_vpc.main.id
    cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
    availability_zone = data.aws_availability_zones.available.names[count.index]
    map_public_ip_on_launch = false
}

#internet gateway + route
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "public" {
    count = 2
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

#security group
resource "aws_security_group" "alb_sg" {
    name = "alb_sg"
    vpc_id = aws_vpc.main.id
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}

resource "aws_security_group" "ec2_sg" {
  name = "ec2_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress  {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#key pair

resource "aws_key_pair" "deployer" {
  key_name   = "demo-key"
  public_key = file("~/aws/demo-ec2.pub")
}

# EC2 instance (backend)

resource "aws_instance" "backend" {
    count = 2
    ami = var.ami_id
    instance_type = "t3.micro"
    subnet_id = aws_subnet.private[count.index].id
    key_name = aws_key_pair.deployer.key_name
    security_groups =  [aws_security_group.ec2_sg.id]
    
   
    tags = {
        Name = "backend-${count.index + 1}"
    }
}

# target group
resource "aws_lb_target_group" "tg" {
  name = "python-app-tg"
  port = 8000
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  health_check {
    path = "/"
    port = "8000"
    protocol = "HTTP"
    interval = 30
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
    matcher = "200"
  }
}

resource "aws_lb_target_group_attachment" "targets" {
  count = 2
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.backend[count.index].id
  port = 8000
}

# Application Load Balancer (ALB)
resource "aws_lb" "alb" {
  name = "demo-alb"
  load_balancer_type = "application"
  subnets = aws_subnet.public[*].id
  security_groups = [aws_security_group.alb_sg.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_security_group" "bastion_sg" {
  name = "bastion-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami = var.ami_id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public[0].id
  key_name = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.bastion_sg.id]
  
  
  tags = {
    Name = "BastionHost"
  }
}