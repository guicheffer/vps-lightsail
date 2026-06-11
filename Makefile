PROFILE ?= personal
REGION  ?= sa-east-1

export AWS_PROFILE=$(PROFILE)
export AWS_REGION=$(REGION)

.DEFAULT_GOAL := help

help: ## show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

setup: ## create VPS + WireGuard (outputs mac-vpn.conf + iPhone QR)
	@bash setup.sh

teardown: ## destroy all AWS resources (no leftover charges)
	@bash teardown.sh

swap-ip: ## release current IP and attach a fresh one
	@bash swap-ip.sh

status: ## show WireGuard peers and handshake status
	@ssh -i $$HOME/.ssh/vps-vpn.pem -o StrictHostKeyChecking=no \
		ubuntu@$$(aws lightsail get-static-ip \
			--static-ip-name vps-vpn-static-ip \
			--region $(REGION) \
			--query 'staticIp.ipAddress' --output text) \
		"sudo wg show"

.PHONY: help setup teardown swap-ip status
