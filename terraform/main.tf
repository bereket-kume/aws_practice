resource "aws_vpc" "my_vpc" {
    cidr_block = var.cide
}

resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-north-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id = aws_subnet.sub1.id
  route_table_id =  aws_route_table.RT.id
}
resource "aws_route_table_association" "rtb2" {
  subnet_id = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "mysg" {
vpc_id = aws_vpc.my_vpc.id
  name = "web-sg"
  ingress {
    description = "Allow HTTP traffic"
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
   ingress  {
    description = "Allow SSH traffic"
    from_port =  22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   }

   egress  {
    description = "Allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
   }
  tags = {
    Name = "web-sg"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "xuri543projectbucket"

}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_instance" "webserver1" {
  ami                    = "ami-042b4708b1d05f512"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id              = aws_subnet.sub1.id
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install apache2 -y
    sudo systemctl enable apache2
    sudo systemctl start apache2
    echo "<!DOCTYPE html>
    <html>
    <head>
        <title>Welcome to My Web Server</title>
    </head>
    <body>
        <h1>Hello, World!</h1>
        <p>Web server 1.</p>
    </body>
    </html>" | sudo tee /var/www/html/index.html
  EOF
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-042b4708b1d05f512"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id              = aws_subnet.sub2.id
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install apache2 -y
    sudo systemctl enable apache2
    sudo systemctl start apache2
    echo "<!DOCTYPE html>
    <html>
    <head>
        <title>Welcome to My Web Server</title>
    </head>
    <body>
        <h1>Hello, World!</h1>
        <p>Web server 2.</p>
    </body>
    </html>" | sudo tee /var/www/html/index.html
  EOF
}

resource "aws_lb" "myalb" {
    name = "my-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.mysg.id]
    subnets = [
        aws_subnet.sub1.id,
        aws_subnet.sub2.id
    ]
}

resource "aws_lb_target_group" "tg" {
  name = "my-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.my_vpc.id
  
  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn =  aws_lb_target_group.tg.arn
  target_id = aws_instance.webserver1.id
  port = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.webserver2.id
  port = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}