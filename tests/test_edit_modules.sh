#!/usr/bin/env bash
# tests/test_edit_modules.sh — JSON update tests for edit_modules
cd "$(dirname "$0")/.."

PASS=0; FAIL=0

pass() { printf 'PASS  %s\n' "$1";                                          PASS=$((PASS+1)); }
fail() { printf 'FAIL  %s\n      expected : %s\n      got      : %s\n' \
             "$1" "$2" "$3";                                                 FAIL=$((FAIL+1)); }
eq()   { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "$2" "$3"; }
has()  { printf '%s' "$3" | grep -qF "$2" && pass "$1" \
             || fail "$1" "(contains) $2" "$3"; }
lacks(){ printf '%s' "$3" | grep -qF "$2" && fail "$1" "(absent) $2" "$3" \
             || pass "$1"; }

# jq selector for a machine entry by name (skips the "match":"default" string entry)
jq_machine() { jq -c --arg mn "$1" \
    '.machines[] | select((.match | type) == "object" and .match.machine_name == $mn)' "${@:2}"; }

# Run edit_modules with pre-set machine variables.
# Write-mode callers should redirect stdout to /dev/null since we don't need the UI output.
em() {
    local mn="$1" mh="$2" cv="$3" ch="$4" gv="$5" gn="$6" gf="$7"; shift 7
    MACHINE_NAME="$mn" MACHINE_HOST="$mh" CPU_VENDOR="$cv" CHIP="$ch" \
    GPU_VENDOR="$gv" GPU_NAME="$gn" GPUS_FOUND="$gf" \
        bash edit_modules "$@"
}

# ── Flags ────────────────────────────────────────────────────────────────────

printf '\n=== flags ===\n'

bash edit_modules --help >/dev/null 2>&1
eq "--help exits 0" "0" "$?"

# ── Dry-run: existing machine ─────────────────────────────────────────────────

printf '\n=== dry-run: existing machine ===\n'

out=$(em Raven MPCDF Intel IceLake NVIDIA A100 true --dry-run < /dev/null 2>&1)
has "dry-run: shows current modules_unload" "gcc"              "$out"
has "dry-run: shows current modules_load"   "intel/2024.1"     "$out"
has "dry-run: shows current env"            "OMP_NUM_THREADS"  "$out"
has "dry-run: file not modified label"      "dry-run"          "$out"

# ── Dry-run: new machine ──────────────────────────────────────────────────────

printf '\n=== dry-run: new machine ===\n'

out=$(em NewMachine "" Intel IceLake none none false --dry-run < /dev/null 2>&1)
has "new machine: creation notice" "new entry will be created" "$out"
has "new machine: dry-run label"   "dry-run"                   "$out"

# ── Write: create new entry ───────────────────────────────────────────────────

printf '\n=== write: create new entry ===\n'

cp modules.json /tmp/_wai_test.json

# Input line order: modules_unload · modules_load · env var · stop · confirm
em TestMachine TestSite AMD Genoa none none false \
    --file /tmp/_wai_test.json >/dev/null 2>&1 <<'EOF'

mycompiler/1.0 openmpi/5.0
MY_VAR=42

y
EOF

entry=$(jq_machine TestMachine /tmp/_wai_test.json)
eq  "new entry: exists"        "1" "$([[ -n "$entry" ]] && echo 1 || echo 0)"

load_mods=$(printf '%s' "$entry" | jq -r '.profiles.default.modules_load[]' 2>/dev/null | tr '\n' ' ')
has "new entry: modules_load has mycompiler" "mycompiler/1.0"  "$load_mods"
has "new entry: modules_load has openmpi"    "openmpi/5.0"     "$load_mods"

env_val=$(printf '%s' "$entry" | jq -r '.profiles.default.env.MY_VAR // ""')
eq  "new entry: MY_VAR env var" "42" "$env_val"

# Entry must appear before the generic "default" fallback
order=$(jq -r '.machines[].description' /tmp/_wai_test.json)
generic_line=$(printf '%s\n' "$order" | grep -n "Generic fallback" | cut -d: -f1)
new_line=$(    printf '%s\n' "$order" | grep -n "TestMachine"      | cut -d: -f1)
eq "new entry: inserted before fallback" "1" "$((new_line < generic_line ? 1 : 0))"

jq . /tmp/_wai_test.json >/dev/null 2>&1
eq "new entry: JSON valid" "0" "$?"

rm -f /tmp/_wai_test.json

# ── Write: update existing profile ───────────────────────────────────────────

printf '\n=== write: update existing profile ===\n'

cp modules.json /tmp/_wai_test.json

# Update Raven gpu profile: bump cuda version, keep everything else
em Raven MPCDF Intel IceLake NVIDIA A100 true \
    --file /tmp/_wai_test.json gpu >/dev/null 2>&1 <<'EOF'
gcc
intel/2024.1 impi/2021.12 cuda/12.6 hdf5-parallel/1.14
OMP_NUM_THREADS=18
I_MPI_PIN=1

y
EOF

raven=$(jq_machine Raven /tmp/_wai_test.json)
gpu_mods=$(printf '%s' "$raven" | jq -r '.profiles.gpu.modules_load[]' | tr '\n' ' ')
has  "updated: new cuda version"           "cuda/12.6"          "$gpu_mods"
lacks "updated: old cuda version absent"   "cuda/12.3"          "$gpu_mods"

# Default profile must be completely untouched
default_mods=$(printf '%s' "$raven" | jq -r '.profiles.default.modules_load[]' | tr '\n' ' ')
has "update: default modules_load preserved" "hdf5-parallel/1.14" "$default_mods"

default_env=$(printf '%s' "$raven" | jq -r '.profiles.default.env.OMP_NUM_THREADS // ""')
eq "update: default env preserved" "18" "$default_env"

jq . /tmp/_wai_test.json >/dev/null 2>&1
eq "update: JSON valid" "0" "$?"

rm -f /tmp/_wai_test.json

# ── Write: dry-run does not modify file ──────────────────────────────────────

printf '\n=== dry-run: file not modified ===\n'

cp modules.json /tmp/_wai_test.json
checksum_before=$(md5sum /tmp/_wai_test.json 2>/dev/null || md5 /tmp/_wai_test.json)

em Raven MPCDF Intel IceLake NVIDIA A100 true \
    --file /tmp/_wai_test.json --dry-run >/dev/null 2>&1 < /dev/null

checksum_after=$(md5sum /tmp/_wai_test.json 2>/dev/null || md5 /tmp/_wai_test.json)
eq "dry-run: file unchanged" "$checksum_before" "$checksum_after"

rm -f /tmp/_wai_test.json

# ── Summary ──────────────────────────────────────────────────────────────────

printf '\n%d passed  %d failed\n' "$PASS" "$FAIL"
exit $((FAIL > 0 ? 1 : 0))
