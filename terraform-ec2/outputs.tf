output "instance_id" {
    value = aws_instance.my_instance.public_ip
    description = "The public IP address of the EC2 instance"
}