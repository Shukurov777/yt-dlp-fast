#!/usr/bin/env bash
set -euo pipefail

# Update yt-dlp and re-apply yt-dlp-fast patches

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/yt-dlp-fast"
LOG_DIR="/var/log/yt-dlp-fast"
LOG_FILE="${LOG_DIR}/install.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "${INSTALL_DIR}" "${LOG_DIR}"

log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
info()    { echo -e "${GREEN}[update]${NC} $*"; log "[INFO] $*"; }
warn()    { echo -e "${YELLOW}[update]${NC} $*"; log "[WARN] $*"; }
error()   { echo -e "${RED}[update]${NC} $*" >&2; log "[ERROR] $*"; }
success() { echo -e "${GREEN}[update OK]${NC} $*"; log "[OK] $*"; }

if [[ "${EUID}" -ne 0 ]]; then
    error "This script must be run as root. Use: sudo ./scripts/update_ytdlp.sh"
    exit 1
fi

log "===== yt-dlp update started ====="

# ── Get current version ───────────────────────────────────────────────────────
OLD_VERSION="$(yt-dlp --version 2>/dev/null || echo 'unknown')"
info "Current yt-dlp version: ${OLD_VERSION}"

# ── Backup current binary ─────────────────────────────────────────────────────
YTDLP_BIN="$(command -v yt-dlp 2>/dev/null || true)"
if [[ -n "${YTDLP_BIN}" ]]; then
    info "Backing up current binary: ${YTDLP_BIN}"
    cp "${YTDLP_BIN}" "${INSTALL_DIR}/yt-dlp.backup"
    echo "${YTDLP_BIN}" > "${INSTALL_DIR}/yt-dlp.backup.path"
    success "Backup saved to ${INSTALL_DIR}/yt-dlp.backup"
else
    warn "yt-dlp not found in PATH; skipping backup."
fi

# ── Update yt-dlp ─────────────────────────────────────────────────────────────
info "Updating yt-dlp via pip..."
if command -v pip3 &>/dev/null; then
    pip3 install --upgrade yt-dlp 2>&1 | tee -a "${LOG_FILE}"
elif command -v pip &>/dev/null; then
    pip install --upgrade yt-dlp 2>&1 | tee -a "${LOG_FILE}"
else
    error "pip not found. Cannot update yt-dlp automatically."
    exit 1
fi

# ── Verify new version ────────────────────────────────────────────────────────
NEW_VERSION="$(yt-dlp --version 2>/dev/null || echo 'unknown')"
if [[ "${NEW_VERSION}" == "${OLD_VERSION}" ]]; then
    info "yt-dlp is already at the latest version: ${NEW_VERSION}"
else
    success "yt-dlp updated: ${OLD_VERSION} → ${NEW_VERSION}"
fi

# ── Re-apply patches ──────────────────────────────────────────────────────────
info "Re-applying performance patches..."
bash "${SCRIPT_DIR}/patch_ytdlp.sh"
success "Patches re-applied."

log "===== yt-dlp update finished: ${NEW_VERSION} ====="
echo ""
echo -e "${GREEN}Update complete. yt-dlp version: ${NEW_VERSION}${NC}"
echo -e "See ${LOG_FILE} for details."
echo ""
