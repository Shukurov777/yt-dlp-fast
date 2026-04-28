#!/usr/bin/env bash
set -euo pipefail

# yt-dlp-fast rollback: restore original yt-dlp binary

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/yt-dlp-fast"
LOG_DIR="/var/log/yt-dlp-fast"
LOG_FILE="${LOG_DIR}/install.log"
BACKUP_FILE="${INSTALL_DIR}/yt-dlp.backup"
BACKUP_PATH_FILE="${INSTALL_DIR}/yt-dlp.backup.path"
APPLIED_FILE="${INSTALL_DIR}/applied_patches.txt"

mkdir -p "${LOG_DIR}"

log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
info()    { echo -e "${GREEN}[rollback]${NC} $*"; log "[INFO] $*"; }
warn()    { echo -e "${YELLOW}[rollback]${NC} $*"; log "[WARN] $*"; }
success() { echo -e "${GREEN}[rollback OK]${NC} $*"; log "[OK] $*"; }

log "===== Rollback started ====="

# ── Restore yt-dlp binary ─────────────────────────────────────────────────────
if [[ -f "${BACKUP_FILE}" ]]; then
    if [[ -f "${BACKUP_PATH_FILE}" ]]; then
        ORIGINAL_PATH="$(cat "${BACKUP_PATH_FILE}")"
    else
        # Guess the most likely location
        ORIGINAL_PATH="$(command -v yt-dlp 2>/dev/null || echo '/usr/local/bin/yt-dlp')"
    fi

    if [[ -n "${ORIGINAL_PATH}" ]]; then
        info "Restoring yt-dlp binary to: ${ORIGINAL_PATH}"
        cp "${BACKUP_FILE}" "${ORIGINAL_PATH}"
        chmod +x "${ORIGINAL_PATH}"
        success "Restored ${ORIGINAL_PATH} from backup."
    else
        warn "Could not determine original yt-dlp path. Backup not restored."
    fi
else
    info "No backup found at ${BACKUP_FILE}. Nothing to restore."
fi

# ── Remove applied patches record ─────────────────────────────────────────────
if [[ -f "${APPLIED_FILE}" ]]; then
    rm -f "${APPLIED_FILE}"
    info "Removed ${APPLIED_FILE}"
fi

log "===== Rollback complete ====="
success "Rollback finished."
