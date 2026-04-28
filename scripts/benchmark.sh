#!/usr/bin/env bash
set -euo pipefail

# yt-dlp-fast benchmark script
# Usage: ./scripts/benchmark.sh <URL>
#
# Compares download performance between safe, fast, and turbo modes.
# NOTE: Results depend on your server, network and CDN. Speedup is not guaranteed.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[bench]${NC} $*"; }
warn()  { echo -e "${YELLOW}[bench]${NC} $*"; }
error() { echo -e "${RED}[bench]${NC} $*" >&2; }

# ── Validate argument ─────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    error "Usage: $0 <URL>"
    exit 1
fi

URL="$1"

if [[ -z "${URL}" ]]; then
    error "URL argument is empty."
    exit 1
fi

if ! [[ "${URL}" =~ ^https?:// ]]; then
    warn "URL does not start with http:// or https:// — proceeding anyway."
fi

# ── Verify yt-dlp is available ────────────────────────────────────────────────
if ! command -v yt-dlp &>/dev/null; then
    error "yt-dlp not found. Please install yt-dlp first."
    exit 1
fi

# ── Create temp directory ─────────────────────────────────────────────────────
BENCH_DIR="$(pwd)/yt-dlp-fast-bench-$$"
mkdir -p "${BENCH_DIR}"

cleanup() {
    if [[ -n "${BENCH_DIR}" && -d "${BENCH_DIR}" ]]; then
        rm -rf "${BENCH_DIR}"
    fi
}
trap cleanup EXIT

# ── Timing helper ─────────────────────────────────────────────────────────────
# Returns elapsed milliseconds in variable ELAPSED_MS
time_run() {
    local start end
    start=$(date +%s%N)
    "$@" || true
    end=$(date +%s%N)
    ELAPSED_MS=$(( (end - start) / 1000000 ))
}

format_ms() {
    local ms="$1"
    if (( ms >= 60000 )); then
        printf "%dm %02ds" $(( ms / 60000 )) $(( (ms % 60000) / 1000 ))
    else
        printf "%d.%03ds" $(( ms / 1000 )) $(( ms % 1000 ))
    fi
}

print_result() {
    local label="$1" ms="$2" baseline_ms="$3"
    local formatted
    formatted="$(format_ms "${ms}")"
    local pct=""
    if [[ "${baseline_ms}" -gt 0 && "${label}" != "SAFE (baseline)" ]]; then
        local improvement=$(( (baseline_ms - ms) * 100 / baseline_ms ))
        if (( improvement > 0 )); then
            pct=" ${GREEN}(${improvement}% faster)${NC}"
        elif (( improvement < 0 )); then
            pct=" ${RED}(${improvement#-}% slower)${NC}"
        else
            pct=" (same speed)"
        fi
    fi
    printf "  %-20s : %s%b\n" "${label}" "${formatted}" "${pct}"
}

# ── Shared yt-dlp options ─────────────────────────────────────────────────────
COMMON_OPTS=(
    --no-playlist
    --max-filesize 30M
    --no-progress
)

aria_args_8="aria2c:-x 8 -s 8 -k 1M --file-allocation=none --summary-interval=0"
aria_args_16="aria2c:-x 16 -s 16 -k 1M --file-allocation=none --summary-interval=0"

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          yt-dlp-fast Benchmark                       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "  URL: ${YELLOW}${URL}${NC}"
echo -e "  Output dir: ${BENCH_DIR}"
echo ""
echo -e "${YELLOW}Each mode will download up to 30MB of the video.${NC}"
echo -e "${YELLOW}Results depend on server, network, and CDN.${NC}"
echo ""

# ── Simulate to get video info ────────────────────────────────────────────────
info "Fetching video info (simulate)..."
VIDEO_INFO="$(yt-dlp --simulate --print "%(title)s | %(format)s | %(filesize_approx)s bytes" \
    "${COMMON_OPTS[@]}" "${URL}" 2>/dev/null | head -1 || echo 'N/A')"
echo -e "  Video info: ${VIDEO_INFO}"
echo ""

# ── Run 1: Safe (baseline) ───────────────────────────────────────────────────
info "Running SAFE mode (baseline, no aria2c)..."
time_run yt-dlp \
    "${COMMON_OPTS[@]}" \
    --fragment-retries 5 --retries 5 --socket-timeout 30 \
    --merge-output-format mp4 \
    -o "${BENCH_DIR}/safe_%(title)s.%(ext)s" \
    "${URL}"
SAFE_MS="${ELAPSED_MS}"

# ── Run 2: Fast ───────────────────────────────────────────────────────────────
info "Running FAST mode (aria2c -x8)..."
time_run yt-dlp \
    "${COMMON_OPTS[@]}" \
    --downloader aria2c \
    --downloader-args "${aria_args_8}" \
    --concurrent-fragments 8 \
    --fragment-retries 10 --retries 10 --socket-timeout 15 \
    --merge-output-format mp4 \
    -o "${BENCH_DIR}/fast_%(title)s.%(ext)s" \
    "${URL}"
FAST_MS="${ELAPSED_MS}"

# ── Run 3: Turbo ──────────────────────────────────────────────────────────────
info "Running TURBO mode (aria2c -x16)..."
time_run yt-dlp \
    "${COMMON_OPTS[@]}" \
    --downloader aria2c \
    --downloader-args "${aria_args_16}" \
    --concurrent-fragments 16 \
    --fragment-retries 10 --retries 10 --socket-timeout 15 \
    --merge-output-format mp4 \
    -o "${BENCH_DIR}/turbo_%(title)s.%(ext)s" \
    "${URL}"
TURBO_MS="${ELAPSED_MS}"

# ── Report ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}══════════════════ RESULTS ════════════════════${NC}"
print_result "SAFE (baseline)" "${SAFE_MS}" "${SAFE_MS}"
print_result "FAST"            "${FAST_MS}"  "${SAFE_MS}"
print_result "TURBO"           "${TURBO_MS}" "${SAFE_MS}"
echo ""
echo -e "${YELLOW}NOTE: Results depend on your server, network and CDN.${NC}"
echo -e "${YELLOW}Speedup is not guaranteed on all sites/CDNs.${NC}"
echo ""
