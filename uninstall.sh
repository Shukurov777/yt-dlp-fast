#!/usr/bin/env bash
set -euo pipefail

# yt-dlp-fast uninstaller

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/yt-dlp-fast"
CONFIG_DIR="/etc/yt-dlp-fast"
LOG_DIR="/var/log/yt-dlp-fast"
BIN_DEST="/usr/local/bin/yt-dlp-fast"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

if [[ "${EUID}" -ne 0 ]]; then
    error "This script must be run as root. Use: sudo ./uninstall.sh"
    exit 1
fi

echo -e "${YELLOW}yt-dlp-fast Uninstaller${NC}"
echo "──────────────────────────────────"

# ── Rollback patches ──────────────────────────────────────────────────────────
info "Rolling back yt-dlp patches (restoring backup)..."
if bash "${SCRIPT_DIR}/scripts/rollback.sh"; then
    success "Rollback completed."
else
    warn "Rollback script encountered issues (may already be clean)."
fi

# ── Remove wrapper binary ────────────────────────────────────────────────────
if [[ -f "${BIN_DEST}" ]]; then
    rm -f "${BIN_DEST}"
    success "Removed ${BIN_DEST}"
else
    info "${BIN_DEST} not found, skipping."
fi

# ── Prompt: remove config ─────────────────────────────────────────────────────
REMOVE_CONFIG="n"
if [[ -d "${CONFIG_DIR}" ]]; then
    read -rp "$(echo -e "${YELLOW}Remove config directory ${CONFIG_DIR}? [y/N]: ${NC}")" REMOVE_CONFIG || true
    if [[ "${REMOVE_CONFIG,,}" == "y" ]]; then
        rm -rf "${CONFIG_DIR}"
        success "Removed ${CONFIG_DIR}"
    else
        info "Kept ${CONFIG_DIR}"
    fi
fi

# ── Prompt: remove logs ───────────────────────────────────────────────────────
REMOVE_LOGS="n"
if [[ -d "${LOG_DIR}" ]]; then
    read -rp "$(echo -e "${YELLOW}Remove log directory ${LOG_DIR}? [y/N]: ${NC}")" REMOVE_LOGS || true
    if [[ "${REMOVE_LOGS,,}" == "y" ]]; then
        rm -rf "${LOG_DIR}"
        success "Removed ${LOG_DIR}"
    else
        info "Kept ${LOG_DIR}"
    fi
fi

# ── Prompt: remove opt directory ─────────────────────────────────────────────
REMOVE_OPT="n"
if [[ -d "${INSTALL_DIR}" ]]; then
    read -rp "$(echo -e "${YELLOW}Remove install directory ${INSTALL_DIR}? [y/N]: ${NC}")" REMOVE_OPT || true
    if [[ "${REMOVE_OPT,,}" == "y" ]]; then
        rm -rf "${INSTALL_DIR}"
        success "Removed ${INSTALL_DIR}"
    else
        info "Kept ${INSTALL_DIR}"
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         yt-dlp-fast uninstalled              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Wrapper removed:  ${GREEN}${BIN_DEST}${NC}"
echo -e "  Config removed:   $(  [[ "${REMOVE_CONFIG,,}" == "y" ]] && echo "${GREEN}yes${NC}" || echo "${YELLOW}no (kept)${NC}")"
echo -e "  Logs removed:     $(  [[ "${REMOVE_LOGS,,}" == "y" ]]   && echo "${GREEN}yes${NC}" || echo "${YELLOW}no (kept)${NC}")"
echo -e "  Opt dir removed:  $(  [[ "${REMOVE_OPT,,}" == "y" ]]    && echo "${GREEN}yes${NC}" || echo "${YELLOW}no (kept)${NC}")"
echo ""
echo -e "  yt-dlp itself is still installed. To remove it: ${YELLOW}pip3 uninstall yt-dlp${NC}"
echo ""
