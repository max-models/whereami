#!/usr/bin/env bash
# tests/test_apple.sh — Apple Silicon detection (run on macOS arm64 only)
cd "$(dirname "$0")/.."

PASS=0; FAIL=0

pass() { printf 'PASS  %s\n' "$1";                                          PASS=$((PASS+1)); }
fail() { printf 'FAIL  %s\n      expected : %s\n      got      : %s\n' \
             "$1" "$2" "$3";                                                 FAIL=$((FAIL+1)); }
eq()   { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "$2" "$3"; }
has()  { printf '%s' "$3" | grep -qF "$2" && pass "$1" \
             || fail "$1" "(contains) $2" "$3"; }

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "SKIP  Not running on macOS arm64 — skipping Apple Silicon tests."
    exit 0
fi

printf '\n=== Apple Silicon detection ===\n'

# Source whereami in a clean subshell; all detection vars are inherited from
# the real macOS environment (no spoofing needed).
d=$(
    (
        unset HOST HOSTNAME HPC_SYSTEM LMOD_ADMIN_FILE NERSC_HOST \
              CI_RUNNER_TAGS PARTITION GXTCUSERDEFINED
        set --
        exec 3>&1 1>/dev/null 2>/dev/null
        source ./whereami
        exec 1>&3 3>&-
        printf 'MACHINE_NAME=%s\nCPU_VENDOR=%s\nCHIP=%s\nGPU_VENDOR=%s\nGPUS_FOUND=%s\n' \
            "${MACHINE_NAME:-}" "${CPU_VENDOR:-}" "${CHIP:-}" "${GPU_VENDOR:-}" "${GPUS_FOUND:-}"
    )
)

field() { printf '%s' "$1" | grep "^$2=" | cut -d= -f2-; }

cpu_vendor=$(field "$d" CPU_VENDOR)
chip=$(field "$d" CHIP)
machine_name=$(field "$d" MACHINE_NAME)

eq  "Apple: CPU_VENDOR is Apple"   "Apple" "$cpu_vendor"
has "Apple: CHIP starts with M"    "M"     "$chip"
has "Apple: MACHINE_NAME non-empty" "Mac"  "$machine_name"

# Verify the script exits 0 (no fatal validation errors)
(
    unset HOST HOSTNAME HPC_SYSTEM LMOD_ADMIN_FILE NERSC_HOST \
          CI_RUNNER_TAGS PARTITION GXTCUSERDEFINED
    set --
    exec 3>&1 1>/dev/null 2>/dev/null
    source ./whereami
    exec 1>&3 3>&-
)
eq "Apple: whereami exits 0" "0" "$?"

printf '\n%d passed  %d failed\n' "$PASS" "$FAIL"
exit $((FAIL > 0 ? 1 : 0))
