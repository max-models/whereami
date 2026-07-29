#!/usr/bin/env bash
# install.sh — install whereami and load_modules into an install directory
#              (default: $HOME/.local/bin)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/max-models/whereami/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/max-models/whereami/main/install.sh | bash -s -- /opt/bin
#   ./install.sh /opt/bin
#   WHEREAMI_INSTALL_DIR=/opt/bin ./install.sh
#   ./install.sh --no-modify-path     # don't touch the shell startup file

set -euo pipefail

# Where the scripts are fetched from.  Override with WHEREAMI_REPO_RAW to
# install from a fork, a tag, or a local checkout ("file:///path/to/whereami").
REPO_RAW="${WHEREAMI_REPO_RAW:-https://raw.githubusercontent.com/max-models/whereami/main}"
FILES=(whereami load_modules edit_modules)

INSTALL_DIR=""
MODIFY_PATH=true
[[ -n "${WHEREAMI_NO_MODIFY_PATH:-}" ]] && MODIFY_PATH=false

_usage() {
    cat <<'EOF'
Usage: install.sh [INSTALL_DIR] [--no-modify-path]

Installs whereami, load_modules and edit_modules into INSTALL_DIR.
INSTALL_DIR defaults to $WHEREAMI_INSTALL_DIR, or $HOME/.local/bin.

If INSTALL_DIR is not already on your PATH, the installer appends an entry
for it to your shell startup file (~/.zshrc, ~/.bashrc, ...).

Options:
  --no-modify-path   Never edit shell startup files; just print the
                     export line to add by hand.  Can also be set with
                     WHEREAMI_NO_MODIFY_PATH=1.
  -h, --help         Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)         _usage; exit 0 ;;
        --no-modify-path)  MODIFY_PATH=false; shift ;;
        -*) echo "ERROR: unknown option: $1" >&2; _usage >&2; exit 1 ;;
        *)
            [[ -z "$INSTALL_DIR" ]] || { echo "ERROR: multiple install dirs given: $INSTALL_DIR and $1" >&2; exit 1; }
            INSTALL_DIR="$1"; shift ;;
    esac
done

[[ -n "$INSTALL_DIR" ]] || INSTALL_DIR="${WHEREAMI_INSTALL_DIR:-${HOME}/.local/bin}"

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
    if [[ "$url" == file://* ]]; then
        cp "${url#file://}" "$dest"
    elif command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget &>/dev/null; then
        wget -qO "$dest" "$url"
    else
        echo -e "${_C_ERR}ERROR: neither curl nor wget found${_C_RESET}" >&2
        exit 1
    fi
}

mkdir -p "$INSTALL_DIR"
# Resolve to an absolute path so messages are unambiguous.  Keep the requested
# spelling too: PATH may well contain the unresolved form (e.g. when $HOME or a
# parent is a symlink), and that still counts as "already on PATH".
REQUESTED_DIR="$INSTALL_DIR"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd -P)"

echo ""
echo -e "${_C_FRAME}┌─────────────────────────────────────┐${_C_RESET}"
echo -e "${_C_FRAME}│${_C_RESET}  ${_C_TITLE}${_C_BOLD}whereami — installer${_C_RESET}                ${_C_FRAME}│${_C_RESET}"
echo -e "${_C_FRAME}└─────────────────────────────────────┘${_C_RESET}"
echo ""
echo -e "  ${_C_DIM}destination:${_C_RESET} ${_C_PATH}${INSTALL_DIR}${_C_RESET}"
echo ""

for f in "${FILES[@]}"; do
    printf "  installing %-15s" "$f"
    _download "${REPO_RAW}/${f}" "${INSTALL_DIR}/${f}"
    chmod +x "${INSTALL_DIR}/${f}"
    echo -e "  ${_C_OK}✓${_C_RESET}"
done

echo ""

#######################################
# PATH setup
#######################################

# Startup file for the user's login shell, plus the syntax it needs.
# Echoes "<file>\t<line>"; empty if the shell is unknown to us.
_shell_startup() {
    local shell_name="${SHELL:-}"
    shell_name="${shell_name##*/}"
    case "$shell_name" in
        zsh)
            printf '%s\t%s' "${ZDOTDIR:-$HOME}/.zshrc" \
                "export PATH=\"${INSTALL_DIR}:\$PATH\"" ;;
        bash)
            # Linux bash reads ~/.bashrc; macOS Terminal starts login shells,
            # which read ~/.bash_profile instead.
            local rc="${HOME}/.bashrc"
            [[ ! -f "$rc" && -f "${HOME}/.bash_profile" ]] && rc="${HOME}/.bash_profile"
            printf '%s\t%s' "$rc" "export PATH=\"${INSTALL_DIR}:\$PATH\"" ;;
        fish)
            printf '%s\t%s' "${HOME}/.config/fish/config.fish" \
                "fish_add_path ${INSTALL_DIR}" ;;
        ksh)
            printf '%s\t%s' "${HOME}/.kshrc" "export PATH=\"${INSTALL_DIR}:\$PATH\"" ;;
        *)  printf '' ;;
    esac
}

_manual_hint() {
    echo -e "  Add this to your shell startup file:"
    echo ""
    echo -e "    ${_C_DIM}export PATH=\"${INSTALL_DIR}:\${PATH}\"${_C_RESET}"
    echo ""
}

_on_path() {
    case ":${PATH}:" in
        *":$1:"*) return 0 ;;
        *)        return 1 ;;
    esac
}

if _on_path "$INSTALL_DIR" || _on_path "$REQUESTED_DIR"; then
    echo -e "  ${_C_PATH}${INSTALL_DIR}${_C_RESET} is already on your PATH."
    echo ""
elif ! $MODIFY_PATH; then
    echo -e "  ${_C_NOTE}NOTE:${_C_RESET} ${_C_PATH}${INSTALL_DIR}${_C_RESET} is not in your PATH."
    _manual_hint
else
    # `read` returns non-zero on empty input (unknown shell) — tolerate it
    IFS=$'\t' read -r _rc _line <<< "$(_shell_startup)" || true
    if [[ -z "${_rc:-}" ]]; then
        echo -e "  ${_C_NOTE}NOTE:${_C_RESET} unrecognized shell (${_C_DIM}${SHELL:-unknown}${_C_RESET}); PATH not modified."
        _manual_hint
    elif [[ -f "$_rc" ]] && grep -Fq "$INSTALL_DIR" "$_rc"; then
        echo -e "  ${_C_PATH}${_rc}${_C_RESET} already references ${_C_PATH}${INSTALL_DIR}${_C_RESET}; leaving it alone."
        echo ""
    else
        mkdir -p "$(dirname "$_rc")"
        {
            echo ""
            echo "# added by whereami installer"
            echo "$_line"
        } >> "$_rc"
        echo -e "  ${_C_OK}✓${_C_RESET} added ${_C_PATH}${INSTALL_DIR}${_C_RESET} to your PATH in ${_C_PATH}${_rc}${_C_RESET}"
        echo -e "    ${_C_DIM}run 'source ${_rc}' or open a new terminal to pick it up${_C_RESET}"
        echo ""
    fi
fi

echo -e "  ${_C_OK}${_C_BOLD}Done.${_C_RESET} Run ${_C_TITLE}whereami${_C_RESET} to detect your machine."
echo ""
