provider "aws" {
    region = "eu-north-1"
}

resource "aws_instance" "my_instance" {
    ami = "ami-05fcfb9614772f051"
    instance_type = "t3.micro" # Example instance type, adjust as needed
    tags = {
        Name = "MyInstance"
    }
}