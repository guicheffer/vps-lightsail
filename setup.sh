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
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$SERVER_IP" "sudo bash" < "$SCRIPT_DIR/provision.sh"

bash "$SCRIPT_DIR/fetch-config.sh" "$SERVER_IP" "$KEY_PATH"

echo ""
echo "✅ Done. Server IP: $SERVER_IP"
echo ""
echo "Next steps:"
echo "  Mac     → open WireGuard app → + → Import tunnel → select mac-vpn.conf"
echo "  iPhone  → open WireGuard app → + → Create from QR code → scan above"
echo "  Verify  → connect, then visit https://ifconfig.me (should show $REGION)"
echo ""
echo "To tear down (no more charges):"
echo "  make teardown"
echo ""
echo "To re-fetch configs from a running server:"
echo "  make config"
echo ""
echo "To add a peer for a friend (no AWS account needed on their end):"
echo "  ssh -i $KEY_PATH ubuntu@$SERVER_IP"
echo "  See CLAUDE.md for full peer setup instructions."
