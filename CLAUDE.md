# CLAUDE.md

## WHAT THIS IS

Personal WireGuard VPN on AWS Lightsail. ~$5/mo.
Pick any region → get a dedicated IP there → route traffic through it.

## FILES

- `setup.sh` — creates VPS + WireGuard from scratch
- `teardown.sh` — destroys everything, no charges left
- `swap-ip.sh` — swap static IP (if flagged or just want a fresh one)
- `README.md` → start here

## HOW IT WORKS

```
Device → WireGuard (UDP 51820) → Lightsail VPS → internet
```

Server: Ubuntu 24.04, wg0 on 10.8.0.1/24
Mac peer: 10.8.0.2 | iPhone peer: 10.8.0.3

## REGION IS A PARAM

```bash
AWS_REGION=sa-east-1 ./setup.sh   # São Paulo
AWS_REGION=eu-west-1 ./setup.sh   # Ireland
```

Default: `sa-east-1`. Override before running.

## AWS PREREQS

IAM user with `lightsail:*` inline policy + access key:
```bash
aws configure --profile personal   # region: sa-east-1
```

## WIREGUARD APPS

- Mac: https://apps.apple.com/app/wireguard/id1451685025
- iPhone: https://apps.apple.com/app/wireguard/id1441195209
- Apple TV: no native app — AirPlay from Mac, or GL.iNet travel router

## USEFUL LINKS

- Lightsail pricing: https://aws.amazon.com/lightsail/pricing/
- Lightsail regions: https://lightsail.aws.amazon.com/ls/docs/en_us/articles/understanding-regions-and-availability-zones-in-amazon-lightsail
- WireGuard quickstart: https://www.wireguard.com/quickstart/
- GL.iNet WireGuard client: https://docs.gl-inet.com/router/en/4/tutorials/wireguard_client/

## COSTS

- $5/mo flat (nano bundle, 512GB transfer included)
- Static IP free while attached — release before teardown or it keeps charging
- swap-ip.sh is free (detach + release + allocate + attach)
