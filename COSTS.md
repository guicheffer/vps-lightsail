# Forecasted Costs

## Fixed

| Resource | Cost |
|---|---|
| Lightsail nano (512MB RAM, 512GB transfer/mo) | **$5.00/mo** |
| Static IP (while attached to running instance) | free |

---

## Transfer usage estimate

> 1080p YouTube ≈ 2–4 GB/hour

| Usage | Data used | vs. 512GB included |
|---|---|---|
| 5h/week (~20h/mo) | ~60–80 GB | 12–16% |
| 10h/week (~40h/mo) | ~120–160 GB | 23–31% |
| 20h/week (~80h/mo) | ~240–320 GB | 47–63% |
| Always-on VPN (all traffic) | varies, can exceed | watch out |

For casual streaming (up to ~20h/week), you stay well within the included 512 GB. **Cost: $5/mo flat.**

---

## If you exceed 512 GB

Lightsail charges $0.09/GB over the bundle limit. Hitting 700 GB in a month would add ~$19 on top.

Recommendation: use the VPN only when needed, not as a permanent always-on tunnel.

---

## Comparison

| Option | Cost | IP type | Speed |
|---|---|---|---|
| **This setup** | ~$5/mo | dedicated | depends on route |
| Surfshark | ~$2–4/mo | shared | shared pool |
| NordVPN | ~$4–6/mo | shared | shared pool |
| ExpressVPN | ~$8–10/mo | shared | shared pool |
| Dedicated IP add-on (NordVPN) | ~$5/mo extra | dedicated | shared infra |

Main advantage here: IP is yours alone, full control, no third party in the middle.
