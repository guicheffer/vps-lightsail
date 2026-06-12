variable "aws_region" {
  description = "AWS region for the Lightsail instance"
  type        = string
  default     = "sa-east-1"
}

variable "availability_zone" {
  description = "Availability zone (must match region)"
  type        = string
  default     = "sa-east-1a"
}

variable "bundle_id" {
  description = "Lightsail bundle (instance size). Run: aws lightsail get-bundles --region <region>"
  type        = string
  default     = "nano_3_1"
}

variable "blueprint_id" {
  description = "Lightsail OS blueprint"
  type        = string
  default     = "ubuntu_24_04"
}

variable "instance_name" {
  description = "Name for the Lightsail instance"
  type        = string
  default     = "personal-vps-vpn"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Path to your SSH private key (used for provisioning)"
  type        = string
  default     = "~/.ssh/id_ed25519"
}
