#!/usr/bin/env bash
set -euo pipefail

# yt-dlp-fast installer
# Installs the yt-dlp-fast wrapper, patches, and dependencies.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/yt-dlp-fast"
CONFIG_DIR="/etc/yt-dlp-fast"
LOG_DIR="/var/log/yt-dlp-fast"
LOG_FILE="${LOG_DIR}/install.log"
BIN_DEST="/usr/local/bin/yt-dlp-fast"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo -e "$msg" | tee -a "${LOG_FILE}"
}

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; log "[INFO]  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; log "[WARN]  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; log "[ERROR] $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; log "[OK]    $*"; }

# ── Root check ──────────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    error "This script must be run as root. Use: sudo ./install.sh"
    exit 1
fi

# ── Create log dir early so we can log everything ───────────────────────────
mkdir -p "${LOG_DIR}"
log "===== yt-dlp-fast installation started ====="

# ── Rollback on error ────────────────────────────────────────────────────────
cleanup_on_error() {
    error "Installation failed. Running rollback..."
    bash "${SCRIPT_DIR}/scripts/rollback.sh" || true
    exit 1
}
trap cleanup_on_error ERR

# ── Detect OS ────────────────────────────────────────────────────────────────
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_ID_LIKE="${ID_LIKE:-}"
    else
        OS_ID="unknown"
        OS_ID_LIKE=""
    fi

    case "${OS_ID}" in
        ubuntu|debian|linuxmint|pop)
            PKG_MANAGER="apt"
            ;;
        centos|rhel|almalinux|rocky|fedora)
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            ;;
        *)
            # Check ID_LIKE as fallback
            if echo "${OS_ID_LIKE}" | grep -qi "debian"; then
                PKG_MANAGER="apt"
            elif echo "${OS_ID_LIKE}" | grep -qi "rhel\|fedora"; then
                PKG_MANAGER="dnf"
            else
                warn "Unknown OS '${OS_ID}'. Assuming apt-based. Install may fail."
                PKG_MANAGER="apt"
            fi
            ;;
    esac
    info "Detected OS: ${OS_ID} (package manager: ${PKG_MANAGER})"
    export PKG_MANAGER
}

detect_os

# ── Install system dependencies ──────────────────────────────────────────────
info "Installing system dependencies..."
bash "${SCRIPT_DIR}/scripts/install_dependencies.sh"
success "Dependencies installed."

# ── Install / update yt-dlp ──────────────────────────────────────────────────
info "Installing / updating yt-dlp..."
if command -v pip3 &>/dev/null; then
    pip3 install --upgrade yt-dlp 2>&1 | tee -a "${LOG_FILE}"
elif command -v pip &>/dev/null; then
    pip install --upgrade yt-dlp 2>&1 | tee -a "${LOG_FILE}"
else
    warn "pip not found. Attempting direct binary install..."
    curl -sSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
        -o /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
fi
success "yt-dlp installed: $(yt-dlp --version 2>/dev/null || echo 'unknown')"

# ── Create directories ───────────────────────────────────────────────────────
info "Creating directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${LOG_DIR}"
success "Directories created."

# ── Install config ───────────────────────────────────────────────────────────
info "Installing configuration..."
cp "${SCRIPT_DIR}/config/yt-dlp-fast.conf" "${CONFIG_DIR}/yt-dlp-fast.conf"
chmod 644 "${CONFIG_DIR}/yt-dlp-fast.conf"
success "Config installed to ${CONFIG_DIR}/yt-dlp-fast.conf"

# ── Install wrapper ──────────────────────────────────────────────────────────
info "Installing wrapper binary..."
cp "${SCRIPT_DIR}/yt-dlp-fast" "${BIN_DEST}"
chmod +x "${BIN_DEST}"
success "Wrapper installed to ${BIN_DEST}"

# ── Backup original yt-dlp ───────────────────────────────────────────────────
YTDLP_BIN="$(command -v yt-dlp 2>/dev/null || true)"
if [[ -n "${YTDLP_BIN}" ]]; then
    info "Backing up original yt-dlp binary: ${YTDLP_BIN}"
    cp "${YTDLP_BIN}" "${INSTALL_DIR}/yt-dlp.backup"
    echo "${YTDLP_BIN}" > "${INSTALL_DIR}/yt-dlp.backup.path"
    success "Backup saved to ${INSTALL_DIR}/yt-dlp.backup"
else
    warn "yt-dlp binary not found in PATH; skipping binary backup."
fi

# ── Apply patches ─────────────────────────────────────────────────────────────
info "Applying performance patches..."
bash "${SCRIPT_DIR}/scripts/patch_ytdlp.sh"
success "Patching complete. See ${INSTALL_DIR}/applied_patches.txt for details."

# ── Done ─────────────────────────────────────────────────────────────────────
trap - ERR
log "===== yt-dlp-fast installation finished successfully ====="
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   yt-dlp-fast installed successfully! 🚀    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Usage:  ${YELLOW}yt-dlp-fast --turbo \"URL\"${NC}"
echo -e "  Config: ${YELLOW}${CONFIG_DIR}/yt-dlp-fast.conf${NC}"
echo -e "  Logs:   ${YELLOW}${LOG_FILE}${NC}"
echo ""
