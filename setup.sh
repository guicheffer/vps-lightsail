#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── config ─────────────────────────────────────────────
# Override via env vars before running:
#   AWS_PROFILE=myprofile AWS_REGION=sa-east-1 ./setup.sh
PROFILE="${AWS_PROFILE:-personal}"
REGION="${AWS_REGION:-sa-east-1}"
AZ="${REGION}a"
INSTANCE="personal-vps-vpn"
KEY_NAME="vps-vpn-key"
KEY_PATH="$HOME/.ssh/vps-vpn.pem"
STATIC_IP_NAME="vps-vpn-static-ip"
BLUEPRINT="${BLUEPRINT:-ubuntu_24_04}"
BUNDLE="${BUNDLE:-nano_3_1}"
# ───────────────────────────────────────────────────────

log() { echo "▶ $*"; }

log "Creating SSH key pair..."
aws lightsail create-key-pair \
  --key-pair-name "$KEY_NAME" \
  --profile "$PROFILE" --region "$REGION" \
  --output json > /tmp/vps-vpn-keypair.json

python3 -c "
import json
with open('/tmp/vps-vpn-keypair.json') as f:
    data = json.load(f)
with open('$KEY_PATH', 'w') as out:
    out.write(data['privateKeyBase64'])
"
chmod 600 "$KEY_PATH"
rm /tmp/vps-vpn-keypair.json

log "Creating Lightsail instance ($REGION)..."
aws lightsail create-instances \
  --instance-names "$INSTANCE" \
  --availability-zone "$AZ" \
  --blueprint-id "$BLUEPRINT" \
  --bundle-id "$BUNDLE" \
  --key-pair-name "$KEY_NAME" \
  --profile "$PROFILE" --region "$REGION" > /dev/null

log "Waiting for instance..."
until [ "$(aws lightsail get-instance \
  --instance-name "$INSTANCE" \
  --profile "$PROFILE" --region "$REGION" \
  --query 'instance.state.name' --output text)" = "running" ]; do
  sleep 5
done

log "Allocating static IP..."
aws lightsail allocate-static-ip \
  --static-ip-name "$STATIC_IP_NAME" \
  --profile "$PROFILE" --region "$REGION" > /dev/null

aws lightsail attach-static-ip \
  --static-ip-name "$STATIC_IP_NAME" \
  --instance-name "$INSTANCE" \
  --profile "$PROFILE" --region "$REGION" > /dev/null

SERVER_IP=$(aws lightsail get-static-ip \
  --static-ip-name "$STATIC_IP_NAME" \
  --profile "$PROFILE" --region "$REGION" \
  --query 'staticIp.ipAddress' --output text)
log "Static IP: $SERVER_IP"

log "Opening firewall ports..."
aws lightsail put-instance-public-ports \
  --instance-name "$INSTANCE" \
  --port-infos '[{"fromPort":22,"toPort":22,"protocol":"tcp"},{"fromPort":51820,"toPort":51820,"protocol":"udp"}]' \
  --profile "$PROFILE" --region "$REGION" > /dev/null

log "Waiting for SSH..."
until ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
  ubuntu@"$SERVER_IP" "echo ok" &>/dev/null; do
  sleep 5
done

log "Configuring server..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$SERVER_IP" "sudo bash" << 'ENDSSH'
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
ENDSSH

bash "$SCRIPT_DIR/fetch-config.sh" "$SERVER_IP" "$KEY_PATH"

echo ""
echo "✅ Done. Server IP: $SERVER_IP"
echo "   Mac:    import mac-vpn.conf into WireGuard app"
echo "   iPhone: scan QR above in WireGuard app"
