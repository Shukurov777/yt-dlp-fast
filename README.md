# # yt-dlp-fast

A high-performance wrapper and patching toolkit for [yt-dlp](https://github.com/yt-dlp/yt-dlp) that leverages `aria2c` multi-connection downloading, concurrent fragment fetching, and optimized yt-dlp internals to maximize download speeds on capable servers.

> **Honest disclaimer:** Speedup depends on your server, network, CDN, and video format. 2x–5x is typical on fast servers. 10x is possible but not guaranteed. `aria2c` may actually be *slower* on some CDNs that rate-limit per connection.

---

## What It Does

- Wraps `yt-dlp` with aggressive parallel download settings (`aria2c -x 16 -s 16`)
- Patches yt-dlp internals to increase default concurrent fragment downloads, optimize chunk sizes, and reduce unnecessary API round-trips
- Provides multiple download modes: `--fast`, `--turbo`, `--safe`, `--audio`, `--video`, `--benchmark`
- Includes a benchmark tool to measure real-world speedup on your server
- Supports easy rollback if patches cause issues

---

## Installation

**Requirements:** Ubuntu/Debian or CentOS/AlmaLinux/Rocky Linux, Python 3.8+, root access.

```bash
git clone https://github.com/shukurov777/yt-dlp-fast.git
cd yt-dlp-fast
chmod +x install.sh
sudo ./install.sh
```

The installer will:
1. Install system dependencies (`ffmpeg`, `aria2`, `python3-pip`, etc.)
2. Install/update `yt-dlp` via pip
3. Apply performance patches to yt-dlp
4. Install the wrapper to `/usr/local/bin/yt-dlp-fast`
5. Install config to `/etc/yt-dlp-fast/yt-dlp-fast.conf`

---

## Usage Examples

### Download with turbo mode (16 parallel connections)
```bash
yt-dlp-fast --turbo "https://www.youtube.com/watch?v=EXAMPLE"
```

### Download audio only (MP3, best quality)
```bash
yt-dlp-fast --audio "https://www.youtube.com/watch?v=EXAMPLE"
```

### Run benchmark on a URL
```bash
yt-dlp-fast --benchmark "https://www.youtube.com/watch?v=EXAMPLE"
```

### Download best video+audio
```bash
yt-dlp-fast --video "https://www.youtube.com/watch?v=EXAMPLE"
```

### Safe mode (no aria2c, conservative retries)
```bash
yt-dlp-fast --safe "https://www.youtube.com/watch?v=EXAMPLE"
```

### Fast mode (8 connections — balanced)
```bash
yt-dlp-fast --fast "https://www.youtube.com/watch?v=EXAMPLE"
```

### Pass any yt-dlp flags through
```bash
yt-dlp-fast --turbo -o "%(title)s.%(ext)s" "URL"
```

---

## Available Modes

| Mode | Connections | Fragments | aria2c | Notes |
|------|-------------|-----------|--------|-------|
| `--fast` | 8 | 8 | ✅ | Balanced speed/stability |
| `--turbo` | 16 | 16 | ✅ | Maximum speed (default) |
| `--safe` | — | — | ❌ | No aria2c, conservative |
| `--audio` | 16 | 16 | ✅ | Extracts MP3 at best quality |
| `--video` | 16 | 16 | ✅ | `bestvideo+bestaudio` format |
| `--benchmark` | — | — | both | Compares safe vs turbo timing |

If no mode flag is given, `--turbo` settings are used by default.

---

## Running a Benchmark

```bash
# Via the wrapper
yt-dlp-fast --benchmark "https://www.youtube.com/watch?v=EXAMPLE"

# Or directly
./scripts/benchmark.sh "https://www.youtube.com/watch?v=EXAMPLE"
```

Output shows elapsed time, estimated speed, file size, and % improvement vs baseline for each mode.

---

## Configuration

Edit `/etc/yt-dlp-fast/yt-dlp-fast.conf` to tune defaults:

```bash
CONCURRENT_FRAGMENTS=16
ARIA2_CONNECTIONS=16
CHUNK_SIZE=1M
SOCKET_TIMEOUT=15
RETRIES=10
```

---

## How to Update yt-dlp

```bash
sudo ./scripts/update_ytdlp.sh
```

This backs up the current binary, updates via pip, and re-applies all patches.

---

## How to Rollback Patches

If patches cause issues:

```bash
sudo ./scripts/rollback.sh
```

This restores the original yt-dlp binary from backup and removes patch records.

---

## Uninstall

```bash
sudo ./uninstall.sh
```

You will be prompted whether to remove configs, logs, and the opt directory.

---

## Limitations

- Speedup depends heavily on the source CDN. YouTube often rate-limits per connection.
- `aria2c` may be slower than the native downloader on sites with per-IP throttling.
- Patches target a specific yt-dlp version range; a major yt-dlp update may require patch regeneration (run `update_ytdlp.sh` to re-apply).
- 10x speedup requires: fast server NIC (1Gbps+), a CDN that allows parallel range requests, and large files (fragmented streams benefit most).
- Some formats (e.g., live streams) cannot use parallel fragment downloading.

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

## Performance Tuning

See [docs/PERFORMANCE.md](docs/PERFORMANCE.md) for tuning guidance and expected results.

## Server Setup

See [docs/SERVER_SETUP.md](docs/SERVER_SETUP.md) for server configuration recommendations.

---

## License

MIT
