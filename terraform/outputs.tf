output "server_ip" {
  description = "Static public IP of the VPN server"
  value       = aws_lightsail_static_ip.vpn.ip_address
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_lightsail_static_ip.vpn.ip_address}"
}

output "next_steps" {
  description = "What to do after apply"
  value       = <<-EOT
    Server ready at ${aws_lightsail_static_ip.vpn.ip_address}

    Fetch client configs:
      ssh -i ${var.ssh_private_key_path} ubuntu@${aws_lightsail_static_ip.vpn.ip_address} \
        "sudo cat /etc/wireguard/mac_private.key && sudo cat /etc/wireguard/server_public.key"

    Or generate iPhone QR:
      ssh -i ${var.ssh_private_key_path} ubuntu@${aws_lightsail_static_ip.vpn.ip_address} \
        "sudo bash -c 'qrencode -t ansiutf8 < <(printf \"[Interface]\nPrivateKey = \$(cat /etc/wireguard/iphone_private.key)\nAddress = 10.8.0.3/32\nDNS = 1.1.1.1\n\n[Peer]\nPublicKey = \$(cat /etc/wireguard/server_public.key)\nEndpoint = ${aws_lightsail_static_ip.vpn.ip_address}:51820\nAllowedIPs = 0.0.0.0/0\nPersistentKeepalive = 25\")'"
  EOT
}
