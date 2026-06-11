#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-personal}"
REGION="${AWS_REGION:-sa-east-1}"

log() { echo "▶ $*"; }

log "Deleting instance..."
aws lightsail delete-instance \
  --instance-name personal-vps-vpn \
  --profile "$PROFILE" --region "$REGION" > /dev/null

log "Detaching static IP..."
aws lightsail detach-static-ip \
  --static-ip-name vps-vpn-static-ip \
  --profile "$PROFILE" --region "$REGION" > /dev/null

sleep 3

log "Releasing static IP..."
aws lightsail release-static-ip \
  --static-ip-name vps-vpn-static-ip \
  --profile "$PROFILE" --region "$REGION" > /dev/null

log "Deleting key pair..."
aws lightsail delete-key-pair \
  --key-pair-name vps-vpn-key \
  --profile "$PROFILE" --region "$REGION" > /dev/null

rm -f "$HOME/.ssh/vps-vpn.pem"

echo "✅ All resources deleted. No more charges."
