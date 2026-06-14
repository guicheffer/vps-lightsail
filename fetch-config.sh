#!/usr/bin/env bash
#
# Fetches WireGuard client material from a running VPN server, writes
# mac-vpn.conf next to this script, and prints the iPhone QR code.
# Shared by setup.sh (shell path) and `make tf-setup` (Terraform path),
# so config-fetching logic lives in one place.
#
# Usage: fetch-config.sh <server_ip> <ssh_key_path>
set -euo pipefail

SERVER_IP="${1:?usage: fetch-config.sh <server_ip> <ssh_key_path>}"
KEY_PATH="${2:?usage: fetch-config.sh <server_ip> <ssh_key_path>}"
KEY_PATH="${KEY_PATH/#\~/$HOME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_PATH="$SCRIPT_DIR/mac-vpn.conf"

ssh_server() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$SERVER_IP" "$@"
}

echo "▶ Fetching client keys..."
SERVER_PUBLIC=$(ssh_server "sudo cat /etc/wireguard/server_public.key")
MAC_PRIVATE=$(ssh_server "sudo cat /etc/wireguard/mac_private.key")
IPHONE_PRIVATE=$(ssh_server "sudo cat /etc/wireguard/iphone_private.key")

cat > "$CONF_PATH" << EOF
[Interface]
PrivateKey = $MAC_PRIVATE
Address = 10.8.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

echo "▶ Mac config saved: $CONF_PATH"
echo "▶ iPhone QR (scan with WireGuard app → + → Create from QR code):"

ssh_server "sudo bash" << EOF
cat > /tmp/iphone-wg.conf << WGEOF
[Interface]
PrivateKey = $IPHONE_PRIVATE
Address = 10.8.0.3/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
WGEOF
qrencode -t ansiutf8 < /tmp/iphone-wg.conf
rm /tmp/iphone-wg.conf
EOF

echo ""
echo "✅ Client configs ready."
echo ""
echo "  Mac    → WireGuard app → + → Import tunnel → $CONF_PATH"
echo "  iPhone → WireGuard app → + → Create from QR code → scan above"
echo "  Verify → https://ifconfig.me (should show server region)"
echo ""
echo "To tear down when done watching:"
echo "  make teardown   (or: make tf-teardown if using Terraform)"
