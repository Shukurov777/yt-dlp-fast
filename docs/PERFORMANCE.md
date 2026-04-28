# Performance Guide for yt-dlp-fast

---

## How Speedup Works

`yt-dlp-fast` combines two mechanisms to accelerate downloads:

### 1. aria2c Multi-Connection Downloading

`aria2c` opens multiple TCP connections to the same server and downloads different byte ranges in parallel. For a 100 MB file with `-x 16 -s 16`, aria2c makes 16 simultaneous range requests each fetching ~6 MB, then reassembles them.

**Why this helps:** Most CDNs throttle per-connection bandwidth. Multiple connections can aggregate more total bandwidth from the same server.

### 2. Concurrent Fragment Downloading

Modern streaming video (HLS/DASH) is delivered as many small segments. yt-dlp normally downloads these sequentially. With `--concurrent-fragments 16`, yt-dlp fetches 16 segments simultaneously.

**Combined effect:** For a 1080p YouTube video with 300 segments, sequential download takes ~300 round-trips; concurrent fetching of 16 at a time reduces that to ~19 batches.

---

## Expected Results

| Scenario | Expected Speedup |
|----------|-----------------|
| Fast server (1 Gbps) + permissive CDN | 3x – 10x |
| Standard VPS (100 Mbps) + YouTube | 1.5x – 3x |
| Home connection (50 Mbps) | 1x – 2x (link-limited) |
| CDN with strict per-IP throttling | 0.8x – 1.2x |
| Live stream or DRM content | No speedup (not fragmentable) |

> **Honest expectation:** 2x–5x is typical for most users with a decent VPS. 10x is possible on bare-metal servers with fast symmetric uplinks downloading from permissive CDNs. **It is not guaranteed.**

---

## Factors Affecting Speed

### CDN Behavior (biggest factor)
- **YouTube:** Applies per-connection bandwidth caps; multiple connections help up to ~8, then diminishing returns.
- **Twitch / generic CDNs:** Often more permissive; turbo mode helps more.
- **DRM content:** Cannot be parallelized at the fragment level.
- **Rate-limited CDNs:** Multiple connections may trigger throttling or bans.

### Server CPU
- muxing (merging video+audio with ffmpeg) is CPU-bound
- fragment assembly is also CPU-bound for large files
- A slow CPU can become the bottleneck even with a fast NIC

### Disk I/O
- Writing 16 fragments simultaneously causes more random I/O than sequential
- NVMe SSD: no impact
- HDD: may become the bottleneck; consider reducing `CONCURRENT_FRAGMENTS`

### Network Latency
- High-latency connections (>100ms RTT) benefit more from parallelism because each connection's wait time is hidden behind others

---

## Tuning Parameters

Edit `/etc/yt-dlp-fast/yt-dlp-fast.conf`:

### `CONCURRENT_FRAGMENTS`
Number of video fragments downloaded simultaneously.
- Default: `16`
- Reduce to `4`–`8` if you get timeout errors or the server throttles you
- Reduce to `1` to match yt-dlp default behavior

### `ARIA2_CONNECTIONS` / `ARIA2_SPLIT`
Number of parallel connections per file (`-x` and `-s` flags for aria2c).
- Default: `16`
- Set to `1` to disable multi-connection (but keep aria2c's resume capability)
- Values above 16 rarely help due to CDN connection limits

### `CHUNK_SIZE`
Minimum split size for aria2c (`-k` flag).
- Default: `1M`
- Increase to `5M` for very large files on fast connections
- Decrease to `512K` for many small fragments

### `SOCKET_TIMEOUT`
Seconds before yt-dlp considers a connection stalled.
- Default: `15`
- Increase to `60` on high-latency or unstable connections

### `RETRIES` / `FRAGMENT_RETRIES`
Number of retry attempts on failure.
- Default: `10`
- Reduce to `3` if you want faster failure detection

---

## Mode Comparison Table

| Mode | aria2c | Connections | Fragments | Timeout | Use Case |
|------|--------|-------------|-----------|---------|----------|
| `--safe` | ❌ | 1 | 1 | 30s | Unstable connections, debugging |
| `--fast` | ✅ | 8 | 8 | 15s | Balanced — good default for most VPS |
| `--turbo` | ✅ | 16 | 16 | 15s | Maximum speed on fast servers |
| `--audio` | ✅ | 16 | 16 | 15s | Extract MP3, skip video |
| `--video` | ✅ | 16 | 16 | 15s | Best quality video+audio |
| `--benchmark` | both | — | — | — | Measure and compare all modes |

---

## Profiling a Download

To see what's happening during a download:

```bash
# View real-time log
tail -f /var/log/yt-dlp-fast/yt-dlp-fast.log

# Run with verbose yt-dlp output
yt-dlp-fast --turbo --verbose "URL" 2>&1 | tee download.log

# Check aria2c status (it prints per-connection speeds to stderr)
yt-dlp-fast --fast "URL"
```

---

## When to Use Each Mode

- **Downloading from YouTube on a standard VPS:** Start with `--fast` (8 connections). If stable, try `--turbo`.
- **Downloading from less-popular sites:** `--turbo` is usually safe and fastest.
- **Slow or unreliable connection:** Use `--safe` to avoid aria2c-induced timeouts.
- **Audio podcasts/music:** `--audio` is most efficient.
- **Comparing performance:** Always run `--benchmark` first on a new server.
