terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── SSH key pair ──────────────────────────────────────────────────────────────

resource "aws_lightsail_key_pair" "vpn" {
  name       = "${var.instance_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ── Instance ──────────────────────────────────────────────────────────────────

resource "aws_lightsail_instance" "vpn" {
  name              = var.instance_name
  availability_zone = var.availability_zone
  blueprint_id      = var.blueprint_id
  bundle_id         = var.bundle_id
  key_pair_name     = aws_lightsail_key_pair.vpn.name

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = self.public_ip_address
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -qq",
      "sudo apt-get upgrade -y -qq",
      "sudo sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config",
      "sudo sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config",
      "sudo systemctl restart ssh",
      "sudo ufw default deny incoming",
      "sudo ufw default allow outgoing",
      "sudo ufw allow 22/tcp",
      "sudo ufw allow 51820/udp",
      "sudo sed -i 's/DEFAULT_FORWARD_POLICY=\"DROP\"/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/' /etc/default/ufw",
      "sudo ufw --force enable",
      "sudo apt-get install -y wireguard qrencode",
      "echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -p",
      "cd /etc/wireguard && sudo wg genkey | sudo tee server_private.key | wg pubkey | sudo tee server_public.key",
      "cd /etc/wireguard && sudo wg genkey | sudo tee mac_private.key | wg pubkey | sudo tee mac_public.key",
      "cd /etc/wireguard && sudo wg genkey | sudo tee iphone_private.key | wg pubkey | sudo tee iphone_public.key",
      "sudo chmod 600 /etc/wireguard/*.key",
      "IFACE=$(ip route | grep default | awk '{print $5}') && sudo bash -c \"cat > /etc/wireguard/wg0.conf << EOF\n[Interface]\nAddress = 10.8.0.1/24\nListenPort = 51820\nPrivateKey = $(sudo cat /etc/wireguard/server_private.key)\nPostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE\nPostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE\n\n[Peer]\nPublicKey = $(sudo cat /etc/wireguard/mac_public.key)\nAllowedIPs = 10.8.0.2/32\n\n[Peer]\nPublicKey = $(sudo cat /etc/wireguard/iphone_public.key)\nAllowedIPs = 10.8.0.3/32\nEOF\"",
      "sudo chmod 600 /etc/wireguard/wg0.conf",
      "sudo systemctl enable wg-quick@wg0",
      "sudo systemctl start wg-quick@wg0",
    ]
  }
}

# ── Firewall ports ────────────────────────────────────────────────────────────

resource "aws_lightsail_instance_public_ports" "vpn" {
  instance_name = aws_lightsail_instance.vpn.name

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
  }

  port_info {
    protocol  = "udp"
    from_port = 51820
    to_port   = 51820
  }
}

# ── Static IP ─────────────────────────────────────────────────────────────────

resource "aws_lightsail_static_ip" "vpn" {
  name = "${var.instance_name}-ip"
}

resource "aws_lightsail_static_ip_attachment" "vpn" {
  static_ip_name = aws_lightsail_static_ip.vpn.name
  instance_name  = aws_lightsail_instance.vpn.name
}
