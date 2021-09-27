provider "aws" {
    region = "us-east-1"    
}

## 1. Create a VPC
resource "aws_vpc" "iac-project-01-vpc" {
    cidr_block = "10.0.0.0/16"
}

## 2. Create Internet Gateway
resource "aws_internet_gateway" "iac-project-01-gw" {
  vpc_id = aws_vpc.iac-project-01-vpc.id

  tags = {
    Name = "iac-project-01-gw"
  }
}
## 3. Create Custom Route Table
resource "aws_route_table" "iac-project-01-route-table" {
  vpc_id = aws_vpc.iac-project-01-vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.iac-project-01-gw.id
  }
  
  route {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.iac-project-01-gw.id
    }

  tags = {
    Name = "web02-pord-route-table"
  }
}

## 4. Create a Subnet
resource "aws_subnet" "iac-project-01-subnet" {
  vpc_id     = aws_vpc.iac-project-01-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "iac-project-01-subnet"
  }
}

## 5. Associate Subnet with the Route Teble
resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.iac-project-01-subnet.id
    route_table_id = aws_route_table.iac-project-01-route-table.id
}


## 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "iac-project-01-allow-http-https-traffic" {
  name        = "allow_http_https"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.iac-project-01-vpc.id

  ingress {
      description      = "HTTPS from VPC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
      description      = "HTTP from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
      description      = "SSH from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_http_https_traffic"
  }
}


## 7. Create a Network Interface with an IP in the Subnet that was created in Step 4
resource "aws_network_interface" "iac-project-01-net-server-nic" {
  subnet_id       = aws_subnet.iac-project-01-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.iac-project-01-allow-http-https-traffic.id]
}

## 8. Assigh an Elastic IP to the Network Interface created in Step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.iac-project-01-net-server-nic.id
  associate_with_private_ip = "10.0.1.50"
}


## 9. Create an Ubuntu Server and Install/Apache2
 resource "aws_instance" "iac-project-01-server-instance" {
   ami               = var.ami_id
   instance_type     = var.instance_type
   #availability_zone = "us-east-1d"
   key_name          = var.key_name
   network_interface {
     device_index         = 0
     network_interface_id = aws_network_interface.iac-project-01-net-server-nic.id
   }
   #Options
   #user_data = file("${path.module}/files/api-data.sh")
   #and inside the api-data.sh put all the commands you want to run on the instance
   #user_data = <<-EOF
   #              #!/bin/bash
   #              sudo apt update -y
   #              sudo apt install apache2 -y
   #              sudo systemctl start apache2
   #              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
   #              EOF
   user_data = file("api-data.sh")
   tags = {
     Name = "iac-project-01-web-server"
   }
 }
