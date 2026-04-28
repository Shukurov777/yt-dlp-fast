#!/usr/bin/env bash
set -euo pipefail

# Install system dependencies for yt-dlp-fast

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG_DIR="/var/log/yt-dlp-fast"
LOG_FILE="${LOG_DIR}/install.log"

mkdir -p "${LOG_DIR}"

log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
info()    { echo -e "${GREEN}[deps]${NC} $*"; log "[INFO] $*"; }
warn()    { echo -e "${YELLOW}[deps]${NC} $*"; log "[WARN] $*"; }
error()   { echo -e "${RED}[deps]${NC} $*" >&2; log "[ERROR] $*"; }
success() { echo -e "${GREEN}[deps OK]${NC} $*"; log "[OK] $*"; }

PACKAGES=(python3 python3-pip git ffmpeg aria2 curl wget)

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    else
        echo "unknown"
    fi
}

PKG_MANAGER="$(detect_pkg_manager)"

case "${PKG_MANAGER}" in
    apt)
        info "Using apt to install dependencies..."
        apt-get update -qq 2>&1 | tee -a "${LOG_FILE}"
        # python3-venv is Debian/Ubuntu specific
        APT_PACKAGES=("${PACKAGES[@]}" python3-venv)
        apt-get install -y "${APT_PACKAGES[@]}" 2>&1 | tee -a "${LOG_FILE}"
        ;;
    dnf)
        info "Using dnf to install dependencies..."
        # Enable EPEL for aria2/ffmpeg on RHEL-based distros
        if command -v dnf &>/dev/null; then
            dnf install -y epel-release 2>&1 | tee -a "${LOG_FILE}" || \
                warn "Could not install epel-release (may already be installed or not needed)"
        fi
        dnf install -y "${PACKAGES[@]}" python3-virtualenv 2>&1 | tee -a "${LOG_FILE}"
        ;;
    yum)
        info "Using yum to install dependencies..."
        yum install -y epel-release 2>&1 | tee -a "${LOG_FILE}" || \
            warn "Could not install epel-release (may already be installed or not needed)"
        yum install -y "${PACKAGES[@]}" python3-virtualenv 2>&1 | tee -a "${LOG_FILE}"
        ;;
    *)
        warn "No supported package manager found (apt/dnf/yum). Attempting to continue..."
        warn "Please install manually: ${PACKAGES[*]}"
        ;;
esac

# ── Verify critical tools ────────────────────────────────────────────────────
MISSING=()
for tool in python3 pip3 ffmpeg aria2c curl; do
    if ! command -v "${tool}" &>/dev/null; then
        MISSING+=("${tool}")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    warn "The following tools were not found after install: ${MISSING[*]}"
    warn "Some features may not work. Install them manually if needed."
else
    success "All required tools are available."
fi

# ── Upgrade pip ──────────────────────────────────────────────────────────────
info "Upgrading pip..."
python3 -m pip install --upgrade pip 2>&1 | tee -a "${LOG_FILE}" || \
    warn "pip upgrade failed (non-fatal)"

success "Dependency installation complete."
