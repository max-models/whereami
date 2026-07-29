#!/usr/bin/env bash
# tests/test_install.sh — installer tests (no network: installs from this checkout)
cd "$(dirname "$0")/.."

REPO="$PWD"

PASS=0; FAIL=0

pass() { printf 'PASS  %s\n' "$1";                                          PASS=$((PASS+1)); }
fail() { printf 'FAIL  %s\n      expected : %s\n      got      : %s\n' \
             "$1" "$2" "$3";                                                 FAIL=$((FAIL+1)); }
eq()   { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "$2" "$3"; }
ok()   { [[ -n "$2" ]] && pass "$1" || fail "$1" "true" "false"; }
has()  { case "$3" in *"$2"*) pass "$1" ;; *) fail "$1" "contains: $2" "$3" ;; esac; }

# Run install.sh against a throwaway HOME with a fake login shell.
# Usage: run_install HOME_DIR SHELL_PATH [install.sh args...]
run_install() {
    local home="$1" shell="$2"; shift 2
    env HOME="$home" SHELL="$shell" WHEREAMI_REPO_RAW="file://${REPO}" \
        PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "${REPO}/install.sh" "$@" 2>&1
}

# pwd -P: macOS hands out /var/... paths that the installer resolves to
# /private/var/..., which would make string comparisons below spurious
_tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$_tmp"' EXIT

# ── Files ────────────────────────────────────────────────────────────────────

printf '\n=== files ===\n'

run_install "$_tmp/h1" /bin/zsh "$_tmp/h1/bin" >/dev/null
for f in whereami load_modules edit_modules; do
    ok "installs $f"     "$([[ -f $_tmp/h1/bin/$f ]] && echo y)"
    ok "$f is executable" "$([[ -x $_tmp/h1/bin/$f ]] && echo y)"
done

# ── PATH setup ───────────────────────────────────────────────────────────────

printf '\n=== PATH setup ===\n'

ok "zsh: writes ~/.zshrc" "$([[ -f $_tmp/h1/.zshrc ]] && echo y)"
has "zsh: exports the install dir" "export PATH=\"$_tmp/h1/bin:\$PATH\"" "$(cat "$_tmp/h1/.zshrc")"

# Re-running must not duplicate the entry
run_install "$_tmp/h1" /bin/zsh "$_tmp/h1/bin" >/dev/null
eq "zsh: second run does not duplicate" "1" \
   "$(grep -c 'added by whereami installer' "$_tmp/h1/.zshrc")"

# bash falls back to ~/.bash_profile when ~/.bashrc is absent
mkdir -p "$_tmp/h2"; touch "$_tmp/h2/.bash_profile"
run_install "$_tmp/h2" /bin/bash "$_tmp/h2/bin" >/dev/null
has "bash: uses existing ~/.bash_profile" "$_tmp/h2/bin" "$(cat "$_tmp/h2/.bash_profile")"
ok  "bash: does not create ~/.bashrc" "$([[ ! -f $_tmp/h2/.bashrc ]] && echo y)"

# fish gets fish syntax, in the fish config location
run_install "$_tmp/h3" /usr/local/bin/fish "$_tmp/h3/bin" >/dev/null
has "fish: uses fish_add_path" "fish_add_path $_tmp/h3/bin" \
    "$(cat "$_tmp/h3/.config/fish/config.fish")"

# Unknown shell: no startup file is invented
run_install "$_tmp/h4" /bin/tcsh "$_tmp/h4/bin" >/dev/null
eq "unknown shell: writes no startup file" "0" \
   "$(find "$_tmp/h4" -maxdepth 1 -name '.*rc' -o -maxdepth 1 -name '.*profile' | wc -l | tr -d ' ')"

# --no-modify-path leaves dotfiles alone
run_install "$_tmp/h5" /bin/zsh "$_tmp/h5/bin" --no-modify-path >/dev/null
ok "--no-modify-path: no ~/.zshrc" "$([[ ! -f $_tmp/h5/.zshrc ]] && echo y)"

# ...and so does WHEREAMI_NO_MODIFY_PATH
mkdir -p "$_tmp/h6"
env HOME="$_tmp/h6" SHELL=/bin/zsh WHEREAMI_REPO_RAW="file://${REPO}" \
    WHEREAMI_NO_MODIFY_PATH=1 bash "${REPO}/install.sh" "$_tmp/h6/bin" >/dev/null 2>&1
ok "WHEREAMI_NO_MODIFY_PATH: no ~/.zshrc" "$([[ ! -f $_tmp/h6/.zshrc ]] && echo y)"

# Already on PATH → nothing to add
mkdir -p "$_tmp/h7/bin"
env HOME="$_tmp/h7" SHELL=/bin/zsh WHEREAMI_REPO_RAW="file://${REPO}" \
    PATH="$_tmp/h7/bin:/usr/bin:/bin" bash "${REPO}/install.sh" "$_tmp/h7/bin" >/dev/null 2>&1
ok "already on PATH: no ~/.zshrc" "$([[ ! -f $_tmp/h7/.zshrc ]] && echo y)"

# PATH holding the unresolved (symlinked) spelling still counts as on PATH
mkdir -p "$_tmp/h11/real/bin"
ln -s "$_tmp/h11/real" "$_tmp/h11/link"
env HOME="$_tmp/h11" SHELL=/bin/zsh WHEREAMI_REPO_RAW="file://${REPO}" \
    PATH="$_tmp/h11/link/bin:/usr/bin:/bin" \
    bash "${REPO}/install.sh" "$_tmp/h11/link/bin" >/dev/null 2>&1
ok "symlinked dir already on PATH: no ~/.zshrc" "$([[ ! -f $_tmp/h11/.zshrc ]] && echo y)"

# ── Install dir resolution ───────────────────────────────────────────────────

printf '\n=== install dir ===\n'

out=$(run_install "$_tmp/h8" /bin/zsh --no-modify-path)
has "defaults to ~/.local/bin" "$_tmp/h8/.local/bin" "$out"
ok  "default dir is populated" "$([[ -x $_tmp/h8/.local/bin/whereami ]] && echo y)"

out=$(env HOME="$_tmp/h9" SHELL=/bin/zsh WHEREAMI_REPO_RAW="file://${REPO}" \
      WHEREAMI_INSTALL_DIR="$_tmp/h9/envdir" bash "${REPO}/install.sh" --no-modify-path 2>&1)
ok "WHEREAMI_INSTALL_DIR is honored" "$([[ -x $_tmp/h9/envdir/whereami ]] && echo y)"

# A relative path is reported as an absolute one
mkdir -p "$_tmp/h10/here"
out=$(cd "$_tmp/h10" && env HOME="$_tmp/h10" SHELL=/bin/zsh \
      WHEREAMI_REPO_RAW="file://${REPO}" bash "${REPO}/install.sh" here --no-modify-path 2>&1)
has "relative dir printed as absolute" "$_tmp/h10/here" "$out"

# ── Flags ────────────────────────────────────────────────────────────────────

printf '\n=== flags ===\n'

bash "${REPO}/install.sh" --help >/dev/null 2>&1
eq "--help exits 0" "0" "$?"

bash "${REPO}/install.sh" --bogus >/dev/null 2>&1; rc=$?
eq "unknown option exits non-zero" "1" "$rc"

bash "${REPO}/install.sh" /a /b >/dev/null 2>&1; rc=$?
eq "two install dirs exit non-zero" "1" "$rc"

# ── Summary ──────────────────────────────────────────────────────────────────

printf '\n%d passed  %d failed\n' "$PASS" "$FAIL"
exit $((FAIL > 0 ? 1 : 0))
