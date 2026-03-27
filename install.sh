#!/usr/bin/env bash
# install.sh — install whereami and load_modules into $HOME/.local/bin
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/max-models/whereami/main/install.sh | bash

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/max-models/whereami/main"
INSTALL_DIR="${HOME}/.local/bin"
FILES=(whereami load_modules)

# Prefer curl, fall back to wget
_download() {
    local url="$1" dest="$2"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget &>/dev/null; then
        wget -qO "$dest" "$url"
    else
        echo "ERROR: neither curl nor wget found" >&2
        exit 1
    fi
}

echo "Installing whereami to ${INSTALL_DIR} ..."

mkdir -p "$INSTALL_DIR"

for f in "${FILES[@]}"; do
    _download "${REPO_RAW}/${f}" "${INSTALL_DIR}/${f}"
    chmod +x "${INSTALL_DIR}/${f}"
    echo "  installed ${INSTALL_DIR}/${f}"
done

# Warn if INSTALL_DIR is not on PATH
case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
        echo ""
        echo "NOTE: ${INSTALL_DIR} is not in your PATH."
        echo "Add the following line to your shell rc file (~/.bashrc, ~/.zshrc, etc.):"
        echo ""
        echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
        echo ""
        ;;
esac

echo "Done. Run 'whereami' to detect your machine."
