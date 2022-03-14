# ---------------------------------------------------------------------------------------------------------------------
# PIN TERRAFORM VERSION TO >= 1.1.6
# The examples have been upgraded to >= 1.1.6 syntax
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.4.0"
    }
  }

  required_version = ">= 1.1.6"
}


# ---------------------------------------------------------------------------------------------------------------------
# DATA SECTION AWS_VPC
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# Default AWS VPC
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

# ---------------------------------------------------------------------------------------------------------------------
# LOOK UP THE LATEST UBUNTU AMI
# ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20211129 ami-04505e74c0741db8d
// ami = "ami-04505e74c0741db8d"
// ami = data.aws_ami.ubuntu.id
# ---------------------------------------------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }


  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20211129"]
  }

  filter {
    name   = "description"
    values = ["Canonical, Ubuntu, 20.04 LTS*"]
  }

}

# ---------------------------------------------------------------------------------------------------------------------
# PROVIDER BLOCK
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}



# ---------------------------------------------------------------------------------------------------------------------
# VARIABLES REQUIRED  which doesn't have default 
# You must provide a value for each of these parameters.
# For now none:
# ---------------------------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------------------------
# VARIABLES OPTIONAL with default placed
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------
variable "key_pair_name" {
  description = "The EC2 Key Pair to associate with the EC2 Instance for SSH access."
  type        = string
  default     = "Ec2-keypair.pem"
}
variable "ssh_port" {
  description = "The port the EC2 Instance should listen on for SSH requests."
  type        = number
  default     = 22
}

variable "ssh_user" {
  description = "SSH user name to use for remote exec connections,"
  type        = string
  default     = "ubuntu"
}

variable "instance_type" {
  description = "The EC2 instace type . For Free its t2.micro ."
  type        = string
  default     = "t2.micro"
}

variable "instance_tags" {
  description = "A list of ec2_ubuntu instances "
  type        = list(string)
  #type = list
  #count = "${var.environment_name == "prd" ? 1 : 0}"
  default = ["Jenkins", "Web"]
}




# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO CONTROL WHAT REQUESTS CAN GO IN AND OUT OF THE EC2 INSTANCES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "ec2_ubuntu_sg" {
  name        = "ec2_ubuntu_sg"
  description = "ec2_ubuntu instance security group for traffic rules"

  # SSH access from anywhere
  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = ["14x.x.x.x/32"]
  }

  # ec2_ubuntu access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # ec2_ubuntu access from anywhere
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Inbound port for the Jenkins instance created"
  }

  # Jenkins slave access from anywhere
  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Inbound port for the Jenkins slave instance created"
  }

  # web access from anywhere
  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Inbound port for the website"
  }

  # web access from anywhere
  ingress {
    from_port   = 4040
    to_port     = 4040
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Inbound port for the website"
  }


  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "ec2_ubuntu_sg"
  }
}
# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE EC2 INSTANCE WITH A PUBLIC IP
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "ec2_ubuntu" {
  for_each                    = toset(var.instance_tags)
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.ec2_ubuntu_sg.id]
  associate_public_ip_address = true
  # Install Jenkins and docker in this instance.
  user_data = file("install_jenkins.sh")
  tags = {
    Name = "${each.key} "
  }

}
output "instances_Public_IP" {
  value = {
    for k, v in aws_instance.ec2_ubuntu : k => v.public_ip
  }
  description = "PublicIP address details"

}

output "instances_Public_DNS" {
  value = {
    for k, v in aws_instance.ec2_ubuntu : k => v.public_dns
  }
  description = "PublicIP address details"

}