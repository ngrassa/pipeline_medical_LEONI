# -------------------------------------------------------
# Data source : récupère le VPC par défaut
# -------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

# -------------------------------------------------------
# Security Group — Ports SSH, Backend, Frontend
# -------------------------------------------------------
resource "aws_security_group" "server_terraform_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security Group for ${var.instance_name}"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend Django
  ingress {
    description = "Django Backend"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Frontend React/Vite
  ingress {
    description = "React Frontend"
    from_port   = 5173
    to_port     = 5173
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress : tout le trafic sortant autorisé
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# -------------------------------------------------------
# Instance EC2 — Ubuntu 24.04 LTS
# -------------------------------------------------------
resource "aws_instance" "server_terraform" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.server_terraform_sg.id]
  associate_public_ip_address = true

  # Volume root gp3 — 25 Go
  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = false

    tags = {
      Name = "${var.instance_name}-root-volume"
    }
  }

  tags = {
    Name = var.instance_name
  }
}

# -------------------------------------------------------
# Elastic IP — IP publique fixe
# -------------------------------------------------------
resource "aws_eip" "server_terraform_eip" {
  instance = aws_instance.server_terraform.id
  domain   = "vpc"

  tags = {
    Name = "${var.instance_name}-eip"
  }

  depends_on = [aws_instance.server_terraform]
}
