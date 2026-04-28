#!/usr/bin/env bash
set -euo pipefail

# yt-dlp-fast installation tests
# Verifies file presence, permissions, and config correctness.
# Does NOT require network access or actual yt-dlp/aria2c.
# Exit code: 0 if all tests pass, 1 if any fail.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

# Resolve repo root relative to this test script
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() { echo -e "${GREEN}[PASS]${NC} $*"; (( PASS++ )) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; (( FAIL++ )) || true; }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

assert_file_exists() {
    local path="$1" desc="${2:-$1}"
    if [[ -f "${path}" ]]; then
        pass "${desc} exists"
    else
        fail "${desc} NOT FOUND: ${path}"
    fi
}

assert_dir_exists() {
    local path="$1" desc="${2:-$1}"
    if [[ -d "${path}" ]]; then
        pass "${desc} directory exists"
    else
        fail "${desc} directory NOT FOUND: ${path}"
    fi
}

assert_executable() {
    local path="$1" desc="${2:-$1}"
    if [[ -x "${path}" ]]; then
        pass "${desc} is executable"
    else
        fail "${desc} is NOT executable: ${path}"
    fi
}

assert_contains() {
    local file="$1" pattern="$2" desc="${3:-pattern '$2' in $1}"
    if grep -qF -- "${pattern}" "${file}" 2>/dev/null; then
        pass "${desc}"
    else
        fail "${desc} — pattern '${pattern}' not found in ${file}"
    fi
}

assert_shebang() {
    local file="$1"
    local first_line
    first_line="$(head -1 "${file}" 2>/dev/null || echo '')"
    if [[ "${first_line}" == "#!/usr/bin/env bash" ]]; then
        pass "$(basename "${file}") has correct shebang"
    else
        fail "$(basename "${file}") shebang is '${first_line}' (expected '#!/usr/bin/env bash')"
    fi
}

assert_set_euo() {
    local file="$1"
    if grep -q 'set -euo pipefail' "${file}" 2>/dev/null; then
        pass "$(basename "${file}") has 'set -euo pipefail'"
    else
        fail "$(basename "${file}") missing 'set -euo pipefail'"
    fi
}

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   yt-dlp-fast Installation Test Suite          ${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "  Repo root: ${REPO_ROOT}"
echo ""

# ── 1. Directory structure ────────────────────────────────────────────────────
info "1. Checking directory structure..."
assert_dir_exists "${REPO_ROOT}/config"    "config/"
assert_dir_exists "${REPO_ROOT}/patches"   "patches/"
assert_dir_exists "${REPO_ROOT}/scripts"   "scripts/"
assert_dir_exists "${REPO_ROOT}/docs"      "docs/"
assert_dir_exists "${REPO_ROOT}/tests"     "tests/"

# ── 2. Root-level files ───────────────────────────────────────────────────────
info "2. Checking root-level files..."
assert_file_exists "${REPO_ROOT}/README.md"       "README.md"
assert_file_exists "${REPO_ROOT}/install.sh"      "install.sh"
assert_file_exists "${REPO_ROOT}/uninstall.sh"    "uninstall.sh"
assert_file_exists "${REPO_ROOT}/yt-dlp-fast"     "yt-dlp-fast (wrapper)"

# ── 3. Config ─────────────────────────────────────────────────────────────────
info "3. Checking config file..."
assert_file_exists "${REPO_ROOT}/config/yt-dlp-fast.conf" "config/yt-dlp-fast.conf"

CONFIG="${REPO_ROOT}/config/yt-dlp-fast.conf"
assert_contains "${CONFIG}" "MODE="                "config: MODE variable"
assert_contains "${CONFIG}" "CONCURRENT_FRAGMENTS=" "config: CONCURRENT_FRAGMENTS variable"
assert_contains "${CONFIG}" "ARIA2_CONNECTIONS="    "config: ARIA2_CONNECTIONS variable"
assert_contains "${CONFIG}" "ARIA2_SPLIT="          "config: ARIA2_SPLIT variable"
assert_contains "${CONFIG}" "CHUNK_SIZE="           "config: CHUNK_SIZE variable"
assert_contains "${CONFIG}" "SOCKET_TIMEOUT="       "config: SOCKET_TIMEOUT variable"
assert_contains "${CONFIG}" "RETRIES="              "config: RETRIES variable"
assert_contains "${CONFIG}" "FRAGMENT_RETRIES="     "config: FRAGMENT_RETRIES variable"
assert_contains "${CONFIG}" "USE_ARIA2="            "config: USE_ARIA2 variable"
assert_contains "${CONFIG}" "USE_FFMPEG="           "config: USE_FFMPEG variable"
assert_contains "${CONFIG}" "LOG_FILE="             "config: LOG_FILE variable"

# ── 4. Patch files ────────────────────────────────────────────────────────────
info "4. Checking patch files..."
assert_file_exists "${REPO_ROOT}/patches/common_fast.patch"     "patches/common_fast.patch"
assert_file_exists "${REPO_ROOT}/patches/http_fast.patch"       "patches/http_fast.patch"
assert_file_exists "${REPO_ROOT}/patches/youtube_fast.patch"    "patches/youtube_fast.patch"
assert_file_exists "${REPO_ROOT}/patches/downloader_fast.patch" "patches/downloader_fast.patch"

for pf in "${REPO_ROOT}/patches/"*.patch; do
    assert_contains "${pf}" "yt-dlp-fast" "$(basename "${pf}") references yt-dlp-fast"
    assert_contains "${pf}" "---"         "$(basename "${pf}") has diff header"
    assert_contains "${pf}" "+++"         "$(basename "${pf}") has diff header"
done

# ── 5. Scripts ────────────────────────────────────────────────────────────────
info "5. Checking scripts..."
SCRIPTS=(
    "scripts/install_dependencies.sh"
    "scripts/patch_ytdlp.sh"
    "scripts/rollback.sh"
    "scripts/benchmark.sh"
    "scripts/update_ytdlp.sh"
)
for s in "${SCRIPTS[@]}"; do
    assert_file_exists "${REPO_ROOT}/${s}" "${s}"
    assert_shebang      "${REPO_ROOT}/${s}"
    assert_set_euo      "${REPO_ROOT}/${s}"
    assert_executable   "${REPO_ROOT}/${s}" "${s} executable"
done

# ── 6. Top-level scripts executable ──────────────────────────────────────────
info "6. Checking top-level script permissions..."
assert_executable "${REPO_ROOT}/install.sh"   "install.sh"
assert_executable "${REPO_ROOT}/uninstall.sh" "uninstall.sh"
assert_executable "${REPO_ROOT}/yt-dlp-fast"  "yt-dlp-fast (wrapper)"

# ── 7. Wrapper content ────────────────────────────────────────────────────────
info "7. Checking wrapper script content..."
WRAPPER="${REPO_ROOT}/yt-dlp-fast"
assert_shebang  "${WRAPPER}"
assert_set_euo  "${WRAPPER}"
assert_contains "${WRAPPER}" "--fast"          "wrapper: --fast mode"
assert_contains "${WRAPPER}" "--turbo"         "wrapper: --turbo mode"
assert_contains "${WRAPPER}" "--safe"          "wrapper: --safe mode"
assert_contains "${WRAPPER}" "--audio"         "wrapper: --audio mode"
assert_contains "${WRAPPER}" "--video"         "wrapper: --video mode"
assert_contains "${WRAPPER}" "--benchmark"     "wrapper: --benchmark mode"
assert_contains "${WRAPPER}" "aria2c"            "wrapper: aria2c usage"
assert_contains "${WRAPPER}" "concurrent-fragments" "wrapper: concurrent-fragments flag"
assert_contains "${WRAPPER}" "CONFIG_FILE"       "wrapper: config file loading"

# ── 8. Documentation ─────────────────────────────────────────────────────────
info "8. Checking documentation files..."
assert_file_exists "${REPO_ROOT}/docs/SERVER_SETUP.md"    "docs/SERVER_SETUP.md"
assert_file_exists "${REPO_ROOT}/docs/PERFORMANCE.md"     "docs/PERFORMANCE.md"
assert_file_exists "${REPO_ROOT}/docs/TROUBLESHOOTING.md" "docs/TROUBLESHOOTING.md"

assert_contains "${REPO_ROOT}/docs/SERVER_SETUP.md"    "BBR"     "SERVER_SETUP: TCP BBR section"
assert_contains "${REPO_ROOT}/docs/PERFORMANCE.md"     "aria2c"  "PERFORMANCE: aria2c explanation"
assert_contains "${REPO_ROOT}/docs/TROUBLESHOOTING.md" "rollback" "TROUBLESHOOTING: rollback instructions"

# ── 9. install.sh content ─────────────────────────────────────────────────────
info "9. Checking install.sh content..."
INSTALL="${REPO_ROOT}/install.sh"
assert_shebang  "${INSTALL}"
assert_set_euo  "${INSTALL}"
assert_contains "${INSTALL}" "EUID"          "install.sh: root check"
assert_contains "${INSTALL}" "rollback.sh"   "install.sh: rollback on error"
assert_contains "${INSTALL}" "patch_ytdlp"   "install.sh: patch call"
assert_contains "${INSTALL}" "LOG_FILE"      "install.sh: logging"

# ── 10. README ────────────────────────────────────────────────────────────────
info "10. Checking README.md..."
README="${REPO_ROOT}/README.md"
assert_contains "${README}" "Installation"   "README: Installation section"
assert_contains "${README}" "Usage"          "README: Usage section"
assert_contains "${README}" "--turbo"        "README: --turbo mode"
assert_contains "${README}" "benchmark"      "README: benchmark section"
assert_contains "${README}" "uninstall"      "README: uninstall section"
assert_contains "${README}" "rollback"       "README: rollback section"
assert_contains "${README}" "not guaranteed" "README: honest disclaimer"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo -e "  Results: ${GREEN}${PASS} PASSED${NC}  ${RED}${FAIL} FAILED${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
    echo -e "${RED}Some tests failed. Review the output above.${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
