variable "aws_region" {
  description = "Région AWS de déploiement"
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Nom de l'instance EC2"
  type        = string
  default     = "server_terraform"
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t2.large"
}

variable "key_name" {
  description = "Nom de la clé SSH dans AWS"
  type        = string
  default     = "vockey"
}

variable "volume_size" {
  description = "Taille du disque root en Go"
  type        = number
  default     = 25
}

variable "volume_type" {
  description = "Type de volume EBS"
  type        = string
  default     = "gp3"
}

variable "ami_id" {
  description = "AMI Ubuntu 24.04 LTS (us-east-1)"
  type        = string
  default     = "ami-0e86e20dae9224db8"
}
