#!/usr/bin/env bash
#
# Server bootstrap for the WireGuard VPN host.
# Runs as root on a fresh Ubuntu 24.04 Lightsail instance.
# Shared by setup.sh (piped to `sudo bash`) and the Terraform provisioner,
# so the provisioning logic lives in one place.
set -e

apt-get update -qq && apt-get upgrade -y -qq

sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 51820/udp
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
ufw --force enable

apt-get install -y wireguard qrencode

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

cd /etc/wireguard
wg genkey | tee server_private.key | wg pubkey | tee server_public.key
wg genkey | tee mac_private.key    | wg pubkey | tee mac_public.key
wg genkey | tee iphone_private.key | wg pubkey | tee iphone_public.key
chmod 600 /etc/wireguard/*.key

IFACE=$(ip route | grep default | awk '{print $5}')
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = $(cat server_private.key)
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE

[Peer]
PublicKey = $(cat mac_public.key)
AllowedIPs = 10.8.0.2/32

[Peer]
PublicKey = $(cat iphone_public.key)
AllowedIPs = 10.8.0.3/32
EOF
chmod 600 /etc/wireguard/wg0.conf

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
