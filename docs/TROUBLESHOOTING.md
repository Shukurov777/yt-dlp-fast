# Troubleshooting yt-dlp-fast

---

## aria2c Not Found

**Symptom:**
```
[yt-dlp-fast] WARNING: aria2c not found in PATH.
```
or
```
ERROR: aria2c: Executable not found
```

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install aria2

# CentOS/AlmaLinux/Rocky
sudo dnf install epel-release && sudo dnf install aria2

# Verify
aria2c --version
```

After installing, retry your download. If aria2c installation fails, use `--safe` mode which does not require it:
```bash
yt-dlp-fast --safe "URL"
```

---

## Patch Failed / Skipped

**Symptom:**
```
[patch] Patch dry-run failed for common_fast.patch (likely already applied or version mismatch)
```

**Explanation:** The patches are designed for yt-dlp 2024.x. A newer or older version may have different source code that causes the patch context lines to not match.

**Fix:**
1. Check which patches were applied:
   ```bash
   cat /opt/yt-dlp-fast/applied_patches.txt
   ```
2. If patches are skipped, `yt-dlp-fast` still works — it just uses the wrapper flags (aria2c, concurrent-fragments) without the internal patches.
3. Update yt-dlp and retry:
   ```bash
   sudo ./scripts/update_ytdlp.sh
   ```
4. If the problem persists, rollback and file an issue:
   ```bash
   sudo ./scripts/rollback.sh
   ```

---

## Permission Denied

**Symptom:**
```
Permission denied: /usr/local/bin/yt-dlp-fast
```
or
```
install.sh: Must be run as root
```

**Fix:**
```bash
# Run installer with sudo
sudo ./install.sh

# Fix wrapper permissions manually if needed
sudo chmod +x /usr/local/bin/yt-dlp-fast
```

---

## yt-dlp Version Mismatch

**Symptom:**
```
[patch] yt-dlp version '2025.x.x' is outside the tested range (2024.x).
```

**Explanation:** Patches were written against yt-dlp 2024.03.10–2024.11.18. A newer version may have refactored the patched files.

**Fix:**
1. Run the update script which will attempt to re-apply patches:
   ```bash
   sudo ./scripts/update_ytdlp.sh
   ```
2. If patches fail, you can still use `yt-dlp-fast` — the wrapper flags provide most of the benefit.
3. File an issue with your yt-dlp version so patches can be regenerated.

---

## Download Slower Than Expected

**Possible causes and fixes:**

| Cause | Fix |
|-------|-----|
| CDN throttles parallel connections | Use `--fast` (8 connections) instead of `--turbo` |
| aria2c overhead on small files | Use `--safe` for files < 10 MB |
| NIC / network is the bottleneck | Check server bandwidth: `curl -o /dev/null https://speed.cloudflare.com/__down?bytes=100000000` |
| Disk I/O bottleneck | Move download target to SSD |
| YouTube rate limiting | Try `--safe` or wait and retry |

Run the benchmark to compare modes on your specific URL:
```bash
./scripts/benchmark.sh "URL"
```

---

## yt-dlp-fast: command not found

**Symptom:**
```bash
$ yt-dlp-fast --turbo "URL"
bash: yt-dlp-fast: command not found
```

**Fix:**
```bash
# Verify the binary is installed
ls -la /usr/local/bin/yt-dlp-fast

# If missing, reinstall
sudo ./install.sh

# Or manually copy
sudo cp yt-dlp-fast /usr/local/bin/yt-dlp-fast
sudo chmod +x /usr/local/bin/yt-dlp-fast
```

---

## ffmpeg Not Found / Merge Failed

**Symptom:**
```
ERROR: ffmpeg not found. Please install or provide the path using the --ffmpeg-location option
```

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# CentOS/AlmaLinux (requires RPM Fusion or EPEL)
sudo dnf install epel-release
sudo dnf install ffmpeg

# Verify
ffmpeg -version
```

---

## Merge output format error

**Symptom:**
```
ERROR: Requested merge format is not available
```

**Fix:** The `--merge-output-format mp4` flag requires both video and audio streams. Try:
```bash
yt-dlp-fast --turbo -f "bestvideo+bestaudio/best" "URL"
# Or use --video mode
yt-dlp-fast --video "URL"
```

---

## How to View Logs

```bash
# Installation log
cat /var/log/yt-dlp-fast/install.log

# Wrapper runtime log
cat /var/log/yt-dlp-fast/yt-dlp-fast.log

# Follow live
tail -f /var/log/yt-dlp-fast/yt-dlp-fast.log

# Check which patches were applied
cat /opt/yt-dlp-fast/applied_patches.txt
```

---

## How to Rollback

If downloads break after installation (e.g., a patch caused yt-dlp to behave incorrectly):

```bash
sudo ./scripts/rollback.sh
```

This restores the original yt-dlp binary from `/opt/yt-dlp-fast/yt-dlp.backup` and removes patch records. The `yt-dlp-fast` wrapper continues to work — it just won't have the internal patches applied.

---

## Common Error Messages

| Error | Meaning | Fix |
|-------|---------|-----|
| `Unable to download webpage` | Network connectivity issue | Check internet access, try `--safe` |
| `HTTP Error 429: Too Many Requests` | Rate limited by server | Wait and retry, use `--safe` with fewer connections |
| `This video is unavailable` | Video restricted or deleted | Nothing to do; try different URL |
| `Sign in to confirm your age` | Age-restricted content | Pass cookies: `--cookies-from-browser chrome` |
| `Premieres in X hours` | Scheduled premiere | Wait for it to go live |
| `Fragment download failed` | Temporary CDN error | Increase `FRAGMENT_RETRIES` or use `--safe` |
| `[generic] Requesting format...` | Format not found | Use `-f bestvideo+bestaudio/best` |
| `patch: command not found` | `patch` utility not installed | `sudo apt-get install patch` |

---

## Getting More Help

1. Run with verbose output:
   ```bash
   yt-dlp-fast --turbo --verbose "URL" 2>&1 | tee verbose.log
   ```
2. Check the yt-dlp documentation: https://github.com/yt-dlp/yt-dlp
3. Check aria2c documentation: https://aria2.github.io/manual/en/html/
