#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-personal}"
REGION="${AWS_REGION:-sa-east-1}"

log() { echo "▶ $*"; }

log "Detaching current IP..."
aws lightsail detach-static-ip \
  --static-ip-name vps-vpn-static-ip \
  --profile "$PROFILE" --region "$REGION" > /dev/null

sleep 2

log "Releasing current IP..."
aws lightsail release-static-ip \
  --static-ip-name vps-vpn-static-ip \
  --profile "$PROFILE" --region "$REGION" > /dev/null

log "Allocating new IP..."
aws lightsail allocate-static-ip \
  --static-ip-name vps-vpn-static-ip \
  --profile "$PROFILE" --region "$REGION" > /dev/null

log "Attaching new IP..."
aws lightsail attach-static-ip \
  --static-ip-name vps-vpn-static-ip \
  --instance-name personal-vps-vpn \
  --profile "$PROFILE" --region "$REGION" > /dev/null

NEW_IP=$(aws lightsail get-static-ip \
  --static-ip-name vps-vpn-static-ip \
  --profile "$PROFILE" --region "$REGION" \
  --query 'staticIp.ipAddress' --output text)

echo "✅ New IP: $NEW_IP"
echo "   Update WireGuard endpoint to: $NEW_IP:51820"
