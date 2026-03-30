#!/usr/bin/env bash
# tests/test_load_modules.sh — profile resolution tests for load_modules
cd "$(dirname "$0")/.."

# load_modules uses negative array indexing (${arr[-1]}) which requires bash 4+.
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    printf 'SKIP  load_modules requires bash 4+ (running bash %s)\n' "$BASH_VERSION"
    exit 0
fi

PASS=0; FAIL=0

pass() { printf 'PASS  %s\n' "$1";                                          PASS=$((PASS+1)); }
fail() { printf 'FAIL  %s\n      expected : %s\n      got      : %s\n' \
             "$1" "$2" "$3";                                                 FAIL=$((FAIL+1)); }
eq()   { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "$2" "$3"; }
has()  { printf '%s' "$3" | grep -qF "$2" && pass "$1" \
             || fail "$1" "(contains) $2" "$3"; }
lacks(){ printf '%s' "$3" | grep -qF "$2" && fail "$1" "(absent) $2" "$3" \
             || pass "$1"; }

# Run load_modules as a script with pre-set machine variables (skips whereami).
# Usage: lm MACHINE_NAME MACHINE_HOST CPU_VENDOR CHIP GPU_VENDOR GPU_NAME GPUS_FOUND [load_modules args...]
# Combines stdout and stderr so callers can grep either.
lm() {
    local mn="$1" mh="$2" cv="$3" ch="$4" gv="$5" gn="$6" gf="$7"; shift 7
    MACHINE_NAME="$mn" MACHINE_HOST="$mh" CPU_VENDOR="$cv" CHIP="$ch" \
    GPU_VENDOR="$gv" GPU_NAME="$gn" GPUS_FOUND="$gf" \
        bash load_modules "$@" 2>&1
}

# ── Flags ────────────────────────────────────────────────────────────────────

printf '\n=== flags ===\n'

bash load_modules --help >/dev/null 2>&1
eq "--help exits 0" "0" "$?"

bash load_modules --file /nonexistent.json 2>/dev/null; rc=$?
eq "missing file exits non-zero" "1" "$rc"

# ── Profile selection ────────────────────────────────────────────────────────

printf '\n=== profile selection ===\n'

# Raven default profile
out=$(lm Raven MPCDF Intel IceLake NVIDIA A100 true --dry-run)
has  "Raven default: gcc unloaded"     "module unload gcc"          "$out"
has  "Raven default: intel loaded"     "module load intel/2024.1"   "$out"
has  "Raven default: hdf5 loaded"      "hdf5-parallel/1.14"         "$out"
has  "Raven default: OMP_NUM_THREADS"  "OMP_NUM_THREADS=18"         "$out"
lacks "Raven default: no cuda"         "cuda"                        "$out"

# Raven gpu profile
out=$(lm Raven MPCDF Intel IceLake NVIDIA A100 true --dry-run gpu)
has  "Raven gpu: cuda loaded"   "module load cuda/12.3"  "$out"
has  "Raven gpu: I_MPI_PIN set" "I_MPI_PIN=1"            "$out"

# LUMI-G default profile
out=$(lm LUMI-G CSC AMD Trento AMD MI250X true --dry-run)
has "LUMI-G default: cray-mpich"  "cray-mpich"    "$out"
has "LUMI-G default: partition/G" "partition/G"   "$out"
lacks "LUMI-G default: no rocm"   "rocm"           "$out"

# LUMI-G gpu profile
out=$(lm LUMI-G CSC AMD Trento AMD MI250X true --dry-run gpu)
has "LUMI-G gpu: rocm"                 "rocm"                   "$out"
has "LUMI-G gpu: MPICH_GPU_SUPPORT"    "MPICH_GPU_SUPPORT_ENABLED=1" "$out"

# Perlmutter gpu profile
out=$(lm Perlmutter NERSC AMD Milan NVIDIA A100 true --dry-run gpu)
has "Perlmutter gpu: cudatoolkit"  "cudatoolkit"       "$out"
has "Perlmutter gpu: cray-hdf5"   "cray-hdf5-parallel" "$out"

# ── Profile fallback ─────────────────────────────────────────────────────────

printf '\n=== profile fallback ===\n'

# LUMI-C has only a "default" profile; requesting "gpu_intel" should fall back
out=$(lm LUMI-C CSC AMD Milan none none false --dry-run gpu_intel)
has  "LUMI-C fallback: warning emitted"     "fallback"    "$out"
has  "LUMI-C fallback: cray-mpich loaded"   "cray-mpich"  "$out"

# Generic NVIDIA fallback for an unknown machine
out=$(lm UnknownBox "" Intel IceLake NVIDIA A100 true --dry-run gpu)
has "generic NVIDIA fallback: cuda"       "cuda/12.3"   "$out"
has "generic NVIDIA fallback: openmpi"    "openmpi/4.1" "$out"

# ── Verbose ──────────────────────────────────────────────────────────────────

printf '\n=== verbose ===\n'

out=$(lm Raven MPCDF Intel IceLake NVIDIA A100 true --verbose --dry-run)
has "verbose: matched description" "Raven — Intel IceLake" "$out"
has "verbose: profile reported"   "Profile : default"      "$out"

# ── Error: no match ──────────────────────────────────────────────────────────

printf '\n=== error handling ===\n'

echo '{"schema_version":3,"machines":[]}' > /tmp/_wai_test_empty.json
lm TestMachine "" Intel IceLake none none false \
    --file /tmp/_wai_test_empty.json 2>/dev/null; rc=$?
eq "no matching machine exits non-zero" "1" "$rc"
rm -f /tmp/_wai_test_empty.json

# ── Summary ──────────────────────────────────────────────────────────────────

printf '\n%d passed  %d failed\n' "$PASS" "$FAIL"
exit $((FAIL > 0 ? 1 : 0))
