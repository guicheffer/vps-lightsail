#!/usr/bin/env bash
set -uo pipefail

PROFILE="${AWS_PROFILE:-personal}"
REGION="${AWS_REGION:-sa-east-1}"

log() { echo "▶ $*"; }

log "Using profile=$PROFILE region=$REGION"

# Runs an AWS CLI step; skips if the resource is already gone, aborts on real errors.
step() {
  local desc="$1"; shift
  log "$desc"
  local out
  if out=$(aws lightsail "$@" --profile "$PROFILE" --region "$REGION" 2>&1); then
    return 0
  fi
  if grep -qiE "NotFoundException|does not exist|not attached" <<< "$out"; then
    log "  skipped (already gone)"
  else
    echo "$out" >&2
    exit 1
  fi
}

step "Deleting instance..." delete-instance --instance-name personal-vps-vpn

step "Detaching static IP..." detach-static-ip --static-ip-name vps-vpn-static-ip

sleep 3

step "Releasing static IP..." release-static-ip --static-ip-name vps-vpn-static-ip

step "Deleting key pair..." delete-key-pair --key-pair-name vps-vpn-key

rm -f "$HOME/.ssh/vps-vpn.pem"

echo "✅ All resources deleted. No more charges."
