#!/usr/bin/env bash
set -euo pipefail

# Apply yt-dlp performance patches

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/yt-dlp-fast"
LOG_DIR="/var/log/yt-dlp-fast"
LOG_FILE="${LOG_DIR}/install.log"
APPLIED_FILE="${INSTALL_DIR}/applied_patches.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="${SCRIPT_DIR}/../patches"

mkdir -p "${INSTALL_DIR}" "${LOG_DIR}"

log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
info()    { echo -e "${GREEN}[patch]${NC} $*"; log "[INFO] $*"; }
warn()    { echo -e "${YELLOW}[patch]${NC} $*"; log "[WARN] $*"; }
error()   { echo -e "${RED}[patch]${NC} $*" >&2; log "[ERROR] $*"; }
success() { echo -e "${GREEN}[patch OK]${NC} $*"; log "[OK] $*"; }

# ── Find yt-dlp package directory ────────────────────────────────────────────
info "Locating yt-dlp installation..."
YTDLP_PACKAGE_DIR=""
if python3 -c "import yt_dlp" 2>/dev/null; then
    YTDLP_PACKAGE_DIR="$(python3 -c "import yt_dlp, os; print(os.path.dirname(yt_dlp.__file__))")"
    info "Found yt_dlp package at: ${YTDLP_PACKAGE_DIR}"
else
    warn "Cannot import yt_dlp. Patches will be skipped."
    echo "# yt_dlp not importable; patches skipped at $(date)" > "${APPLIED_FILE}"
    exit 0
fi

# ── Check yt-dlp version ─────────────────────────────────────────────────────
YTDLP_VERSION=""
if command -v yt-dlp &>/dev/null; then
    YTDLP_VERSION="$(yt-dlp --version 2>/dev/null || echo 'unknown')"
    info "yt-dlp version: ${YTDLP_VERSION}"
    # Warn if outside tested range (2024.x)
    if [[ ! "${YTDLP_VERSION}" =~ ^2024\. ]] && [[ "${YTDLP_VERSION}" != "unknown" ]]; then
        warn "yt-dlp version '${YTDLP_VERSION}' is outside the tested range (2024.x)."
        warn "Patches may not apply cleanly. Proceeding anyway..."
    fi
fi

# ── Initialize applied patches record ────────────────────────────────────────
{
    echo "# yt-dlp-fast applied patches"
    echo "# Date: $(date)"
    echo "# yt-dlp version: ${YTDLP_VERSION}"
    echo "# yt-dlp package dir: ${YTDLP_PACKAGE_DIR}"
    echo ""
} > "${APPLIED_FILE}"

# ── Apply each patch ──────────────────────────────────────────────────────────
PATCHES=(
    "common_fast.patch:downloader/common.py"
    "http_fast.patch:downloader/http.py"
    "youtube_fast.patch:extractor/youtube.py"
    "downloader_fast.patch:downloader/external.py"
)

APPLIED=0
SKIPPED=0

for entry in "${PATCHES[@]}"; do
    PATCH_FILE="${entry%%:*}"
    TARGET_REL="${entry##*:}"
    PATCH_PATH="${PATCHES_DIR}/${PATCH_FILE}"
    TARGET_PATH="${YTDLP_PACKAGE_DIR}/${TARGET_REL}"

    if [[ ! -f "${PATCH_PATH}" ]]; then
        warn "Patch file not found: ${PATCH_PATH} — skipping"
        echo "SKIPPED (not found): ${PATCH_FILE}" >> "${APPLIED_FILE}"
        (( SKIPPED++ )) || true
        continue
    fi

    if [[ ! -f "${TARGET_PATH}" ]]; then
        warn "Target file not found: ${TARGET_PATH} — skipping ${PATCH_FILE}"
        echo "SKIPPED (target missing): ${PATCH_FILE}" >> "${APPLIED_FILE}"
        (( SKIPPED++ )) || true
        continue
    fi

    info "Applying ${PATCH_FILE} to ${TARGET_PATH}..."
    # Attempt dry-run first
    if patch --dry-run -p1 -d "${YTDLP_PACKAGE_DIR}" < "${PATCH_PATH}" &>>"${LOG_FILE}"; then
        if patch -p1 -d "${YTDLP_PACKAGE_DIR}" < "${PATCH_PATH}" &>>"${LOG_FILE}"; then
            success "Applied: ${PATCH_FILE}"
            echo "APPLIED: ${PATCH_FILE}" >> "${APPLIED_FILE}"
            (( APPLIED++ )) || true
        else
            warn "Patch apply failed (dry-run passed): ${PATCH_FILE} — skipping"
            echo "FAILED: ${PATCH_FILE}" >> "${APPLIED_FILE}"
            (( SKIPPED++ )) || true
        fi
    else
        warn "Patch dry-run failed for ${PATCH_FILE} (likely already applied or version mismatch) — skipping"
        echo "SKIPPED (dry-run failed): ${PATCH_FILE}" >> "${APPLIED_FILE}"
        (( SKIPPED++ )) || true
    fi
done

info "Patching summary: ${APPLIED} applied, ${SKIPPED} skipped."
info "Record written to: ${APPLIED_FILE}"
