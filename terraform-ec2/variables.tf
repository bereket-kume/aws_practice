variable "aws_region" { 
    description = "the aws region to deploy the instance in"
    default     = "us-north-1"
}

variable "aws_ami" {
    description = "the AMI to use for the instance"
    default     = "ami-0c55b159cbfafe1f0" # Example AMI ID, replace with a valid one for your region
}

variable "aws_instance_type" {
    description = "the type of instance to create"
    default    = "t2.micro" # Example instance type, adjust as needed
}