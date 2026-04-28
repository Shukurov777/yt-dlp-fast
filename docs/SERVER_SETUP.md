# Server Setup Guide for yt-dlp-fast

This guide covers server configuration to maximize download throughput when using `yt-dlp-fast`.

---

## Minimum Server Requirements

| Component | Minimum | Notes |
|-----------|---------|-------|
| CPU | 1 vCPU / 1 GHz | Muxing/transcoding is CPU-bound |
| RAM | 512 MB | 1 GB recommended for concurrent downloads |
| Disk | 10 GB free | SSD strongly preferred |
| Network | 100 Mbps NIC | Faster NIC = higher potential throughput |
| OS | Ubuntu 20.04+ / AlmaLinux 8+ | Other Linux distros supported |

## Recommended Server Specs

| Component | Recommended |
|-----------|-------------|
| CPU | 4+ cores @ 2.5 GHz+ |
| RAM | 4 GB+ |
| Disk | NVMe SSD, 50+ GB |
| Network | 1 Gbps dedicated NIC |
| OS | Ubuntu 22.04 LTS |

> **Note:** A fast NIC is the most impactful factor. On a 100 Mbps link, parallel connections won't help much if the link is the bottleneck.

---

## Network Optimization

### Enable TCP BBR Congestion Control

BBR (Bottleneck Bandwidth and RTT) can improve throughput significantly on modern kernels.

```bash
# Check current algorithm
sysctl net.ipv4.tcp_congestion_control

# Enable BBR (requires kernel 4.9+)
echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Verify
sysctl net.ipv4.tcp_congestion_control
# Should output: net.ipv4.tcp_congestion_control = bbr
```

### Increase Socket Buffer Sizes

Larger buffers reduce retransmissions on high-latency links:

```bash
# Add to /etc/sysctl.conf
cat >> /etc/sysctl.conf << 'EOF'
# yt-dlp-fast network tuning
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_window_scaling = 1
EOF

sudo sysctl -p
```

### DNS Optimization

Fast DNS resolution reduces first-connection latency:

```bash
# Use fast public DNS resolvers
echo 'nameserver 1.1.1.1' | sudo tee /etc/resolv.conf
echo 'nameserver 8.8.8.8' | sudo tee -a /etc/resolv.conf
```

---

## Firewall / iptables Notes

`yt-dlp-fast` makes outbound HTTP/HTTPS connections. Most default configurations allow this. If you use strict egress filtering:

```bash
# Allow outbound HTTP and HTTPS
sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Allow established/related inbound
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

If using `ufw`:
```bash
sudo ufw allow out 80/tcp
sudo ufw allow out 443/tcp
```

---

## Optional: Run yt-dlp-fast as a Systemd Service

If you want to run scheduled or queued downloads as a background service:

```ini
# /etc/systemd/system/yt-dlp-fast@.service
[Unit]
Description=yt-dlp-fast download job for %i
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=nobody
Group=nogroup
ExecStart=/usr/local/bin/yt-dlp-fast --turbo %I
StandardOutput=append:/var/log/yt-dlp-fast/service.log
StandardError=append:/var/log/yt-dlp-fast/service.log
TimeoutStopSec=3600

[Install]
WantedBy=multi-user.target
```

Enable and trigger a download:
```bash
sudo systemctl daemon-reload
# URL must be URL-encoded or passed via environment; simpler to use a queue script
sudo systemctl start "yt-dlp-fast@https:--www.youtube.com-watch?v=EXAMPLE"
```

For a proper queue, consider a simple wrapper:
```bash
#!/usr/bin/env bash
# /usr/local/bin/yt-dlp-queue
while IFS= read -r url; do
    /usr/local/bin/yt-dlp-fast --turbo "${url}"
done < /var/spool/yt-dlp-fast/queue.txt
```

---

## Disk I/O Optimization

- Use an SSD or NVMe for the download destination.
- Avoid network file systems (NFS/CIFS) as download destinations — they add latency.
- If using HDDs, set the `--downloader-args` `--file-allocation=falloc` to pre-allocate and reduce fragmentation:
  ```
  CHUNK_SIZE=1M  # keep small if HDD
  ```

---

## Monitoring Download Performance

```bash
# Watch live network throughput
watch -n1 'cat /proc/net/dev | grep -E "eth0|ens|enp"'

# Or use nload / iftop
nload eth0
```
