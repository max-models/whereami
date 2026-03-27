#!/usr/bin/env bash
# install.sh — install whereami and load_modules into $HOME/.local/bin
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/max-models/whereami/main/install.sh | bash

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/max-models/whereami/main"
INSTALL_DIR="${HOME}/.local/bin"
FILES=(whereami load_modules)

# Colors
_C_RESET="\033[0m"
_C_BOLD="\033[1m"
_C_TITLE="\033[1;36m"   # bold cyan
_C_PATH="\033[0;33m"    # yellow
_C_OK="\033[1;32m"      # bold green
_C_NOTE="\033[0;33m"    # yellow
_C_ERR="\033[1;31m"     # bold red
_C_DIM="\033[0;90m"     # dark gray
_C_FRAME="\033[0;36m"   # cyan

# Prefer curl, fall back to wget
_download() {
    local url="$1" dest="$2"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget &>/dev/null; then
        wget -qO "$dest" "$url"
    else
        echo -e "${_C_ERR}ERROR: neither curl nor wget found${_C_RESET}" >&2
        exit 1
    fi
}

echo ""
echo -e "${_C_FRAME}┌─────────────────────────────────────┐${_C_RESET}"
echo -e "${_C_FRAME}│${_C_RESET}  ${_C_TITLE}${_C_BOLD}whereami — installer${_C_RESET}                ${_C_FRAME}│${_C_RESET}"
echo -e "${_C_FRAME}└─────────────────────────────────────┘${_C_RESET}"
echo ""
echo -e "  ${_C_DIM}destination:${_C_RESET} ${_C_PATH}${INSTALL_DIR}${_C_RESET}"
echo ""

mkdir -p "$INSTALL_DIR"

for f in "${FILES[@]}"; do
    printf "  installing %-15s" "$f"
    _download "${REPO_RAW}/${f}" "${INSTALL_DIR}/${f}"
    chmod +x "${INSTALL_DIR}/${f}"
    echo -e "  ${_C_OK}✓${_C_RESET}"
done

echo ""

# Warn if INSTALL_DIR is not on PATH
case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
        echo -e "  ${_C_NOTE}NOTE:${_C_RESET} ${_C_PATH}${INSTALL_DIR}${_C_RESET} is not in your PATH."
        echo -e "  Add this to your ${_C_DIM}~/.bashrc${_C_RESET} or ${_C_DIM}~/.zshrc${_C_RESET}:"
        echo ""
        echo -e "    ${_C_DIM}export PATH=\"\${HOME}/.local/bin:\${PATH}\"${_C_RESET}"
        echo ""
        ;;
esac

echo -e "  ${_C_OK}${_C_BOLD}Done.${_C_RESET} Run ${_C_TITLE}whereami${_C_RESET} to detect your machine."
echo ""
