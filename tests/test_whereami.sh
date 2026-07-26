#!/usr/bin/env bash
# tests/test_whereami.sh — machine detection tests for whereami
cd "$(dirname "$0")/.."

PASS=0; FAIL=0

pass() { printf 'PASS  %s\n' "$1";                                          PASS=$((PASS+1)); }
fail() { printf 'FAIL  %s\n      expected : %s\n      got      : %s\n' \
             "$1" "$2" "$3";                                                 FAIL=$((FAIL+1)); }
eq()   { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "$2" "$3"; }

# Run whereami in a subshell with a clean set of detection variables.
# Unsets all HPC env vars so only the ones passed as arguments are active.
# Output: one KEY=VALUE line per exported variable.
detect() {
    (
        unset HOST HOSTNAME HPC_SYSTEM LMOD_ADMIN_FILE NERSC_HOST \
              CI_RUNNER_TAGS PARTITION GXTCUSERDEFINED
        for _kv in "$@"; do export "$_kv"; done
        set --   # clear $@ so whereami's arg-parser doesn't see our KEY=VALUE pairs
        exec 3>&1 1>/dev/null 2>/dev/null
        source ./whereami
        exec 1>&3 3>&-
        printf 'MACHINE_NAME=%s\nMACHINE_HOST=%s\nCPU_VENDOR=%s\nCHIP=%s\nGPU_VENDOR=%s\nGPU_NAME=%s\nGPUS_FOUND=%s\n' \
            "${MACHINE_NAME:-}" "${MACHINE_HOST:-}" "${CPU_VENDOR:-}" \
            "${CHIP:-}" "${GPU_VENDOR:-}" "${GPU_NAME:-}" "${GPUS_FOUND:-}"
    )
}

# Extract one field from detect() output
field() { printf '%s' "$1" | grep "^$2=" | cut -d= -f2-; }

# ── Flags ────────────────────────────────────────────────────────────────────

printf '\n=== flags ===\n'

bash whereami --help >/dev/null 2>&1
eq "--help exits 0" "0" "$?"

bash whereami --unknown >/dev/null 2>&1; rc=$?
eq "unknown option exits non-zero" "1" "$rc"

bash whereami -o >/dev/null 2>&1; rc=$?
eq "--output without FILE exits non-zero" "1" "$rc"

# ── JSON output ──────────────────────────────────────────────────────────────

printf '\n=== json output ===\n'

_out_dir=$(mktemp -d)

(
    unset HOST HOSTNAME HPC_SYSTEM LMOD_ADMIN_FILE NERSC_HOST \
          CI_RUNNER_TAGS PARTITION GXTCUSERDEFINED
    export HOST=raven1
    bash whereami -o "${_out_dir}/nested/info.json"
) >/dev/null 2>&1
eq "-o writes the file (creating parent dirs)" "0" "$([[ -f ${_out_dir}/nested/info.json ]] && echo 0 || echo 1)"

if command -v jq &>/dev/null; then
    j="${_out_dir}/nested/info.json"
    eq "-o produces valid JSON" "0" "$(jq -e . "$j" >/dev/null 2>&1; echo $?)"
    eq "-o MACHINE_NAME" "Raven"   "$(jq -r .MACHINE_NAME "$j")"
    eq "-o CHIP"         "IceLake" "$(jq -r .CHIP "$j")"
    eq "-o GPUS_FOUND is a boolean" "boolean" "$(jq -r '.GPUS_FOUND|type' "$j")"
else
    printf 'SKIP  json content checks (jq not found)\n'
fi

# --output=FILE form
(
    unset HOST HOSTNAME HPC_SYSTEM LMOD_ADMIN_FILE NERSC_HOST \
          CI_RUNNER_TAGS PARTITION GXTCUSERDEFINED
    export HOST=raven1
    bash whereami --output="${_out_dir}/eq.json"
) >/dev/null 2>&1
eq "--output=FILE writes the file" "0" "$([[ -f ${_out_dir}/eq.json ]] && echo 0 || echo 1)"

# Sourcing with -o must not clobber the caller's positional parameters
set -- keep1 keep2
source ./whereami -o "${_out_dir}/sourced.json" >/dev/null 2>&1
eq "sourced -o leaves \$@ intact" "keep1 keep2" "$*"
set --

rm -rf "$_out_dir"

# ── Machine detection ────────────────────────────────────────────────────────

printf '\n=== machine detection ===\n'

# Raven — detected via HOST
d=$(detect HOST=raven1)
eq "Raven  MACHINE_NAME"  "Raven"   "$(field "$d" MACHINE_NAME)"
eq "Raven  MACHINE_HOST"  "MPCDF"   "$(field "$d" MACHINE_HOST)"
eq "Raven  CPU_VENDOR"    "Intel"   "$(field "$d" CPU_VENDOR)"
eq "Raven  CHIP"          "IceLake" "$(field "$d" CHIP)"
eq "Raven  GPU_NAME"      "A100"    "$(field "$d" GPU_NAME)"
eq "Raven  GPUS_FOUND"    "true"    "$(field "$d" GPUS_FOUND)"

# Viper-GPU — hostname contains "viper12"
d=$(detect HOSTNAME=viper12-001)
eq "Viper-GPU  MACHINE_NAME" "Viper-GPU" "$(field "$d" MACHINE_NAME)"
eq "Viper-GPU  CHIP"         "Genoa"     "$(field "$d" CHIP)"
eq "Viper-GPU  GPU_NAME"     "MI300A"    "$(field "$d" GPU_NAME)"
eq "Viper-GPU  GPUS_FOUND"   "true"      "$(field "$d" GPUS_FOUND)"

# Viper-CPU — hostname contains "viper" but not "viper12"
d=$(detect HOSTNAME=viper-001)
eq "Viper-CPU  MACHINE_NAME" "Viper-CPU" "$(field "$d" MACHINE_NAME)"
eq "Viper-CPU  GPU_VENDOR"   "none"      "$(field "$d" GPU_VENDOR)"
eq "Viper-CPU  GPUS_FOUND"   "false"     "$(field "$d" GPUS_FOUND)"

# Cobra — detected via HOST
d=$(detect HOST=cobra1)
eq "Cobra  MACHINE_NAME" "Cobra"      "$(field "$d" MACHINE_NAME)"
eq "Cobra  CHIP"         "SkyLake"    "$(field "$d" CHIP)"
eq "Cobra  GPU_NAME"     "Tesla V100" "$(field "$d" GPU_NAME)"

# LUMI-G — LMOD_ADMIN_FILE contains "lumi", explicit partition
d=$(detect LMOD_ADMIN_FILE=/opt/lumi/lmod/admin PARTITION=LUMI-G)
eq "LUMI-G  MACHINE_NAME" "LUMI-G"  "$(field "$d" MACHINE_NAME)"
eq "LUMI-G  CPU_VENDOR"   "AMD"     "$(field "$d" CPU_VENDOR)"
eq "LUMI-G  CHIP"         "Trento"  "$(field "$d" CHIP)"
eq "LUMI-G  GPU_NAME"     "MI250X"  "$(field "$d" GPU_NAME)"

# LUMI-C
d=$(detect LMOD_ADMIN_FILE=/opt/lumi/lmod/admin PARTITION=LUMI-C)
eq "LUMI-C  MACHINE_NAME" "LUMI-C" "$(field "$d" MACHINE_NAME)"
eq "LUMI-C  CHIP"         "Milan"  "$(field "$d" CHIP)"
eq "LUMI-C  GPU_VENDOR"   "none"   "$(field "$d" GPU_VENDOR)"

# Leonardo Booster — HPC_SYSTEM + explicit partition
d=$(detect HPC_SYSTEM=leonardo PARTITION=Booster)
eq "Leonardo Booster  MACHINE_NAME" "Leonardo (Booster)" "$(field "$d" MACHINE_NAME)"
eq "Leonardo Booster  CHIP"         "IceLake"             "$(field "$d" CHIP)"
eq "Leonardo Booster  GPU_NAME"     "A100"                "$(field "$d" GPU_NAME)"

# Leonardo DCGP — any non-Booster partition
d=$(detect HPC_SYSTEM=leonardo PARTITION=DCGP)
eq "Leonardo DCGP  MACHINE_NAME" "Leonardo (DCGP)" "$(field "$d" MACHINE_NAME)"
eq "Leonardo DCGP  CHIP"         "SapphireRapids"  "$(field "$d" CHIP)"
eq "Leonardo DCGP  GPU_VENDOR"   "none"            "$(field "$d" GPU_VENDOR)"

# Pitagora DCGP
d=$(detect HPC_SYSTEM=pitagora)
eq "Pitagora  MACHINE_NAME" "Pitagora (DCGP)" "$(field "$d" MACHINE_NAME)"
eq "Pitagora  CHIP"         "Genoa"           "$(field "$d" CHIP)"

# Perlmutter
d=$(detect NERSC_HOST=perlmutter)
eq "Perlmutter  MACHINE_NAME" "Perlmutter" "$(field "$d" MACHINE_NAME)"
eq "Perlmutter  CHIP"         "Milan"      "$(field "$d" CHIP)"
eq "Perlmutter  GPU_NAME"     "A100"       "$(field "$d" GPU_NAME)"

# TOK — detected via HOST
d=$(detect HOST=toki-001)
eq "TOK  MACHINE_NAME" "TOK"   "$(field "$d" MACHINE_NAME)"
eq "TOK  CHIP"         "Genoa" "$(field "$d" CHIP)"

# Vega GPU — default partition
d=$(detect HOSTNAME=vega001)
eq "Vega GPU  MACHINE_NAME" "Vega (GPU)" "$(field "$d" MACHINE_NAME)"
eq "Vega GPU  GPU_NAME"     "A100"       "$(field "$d" GPU_NAME)"
eq "Vega GPU  GPUS_FOUND"   "true"       "$(field "$d" GPUS_FOUND)"

# Vega CPU — explicit partition
d=$(detect HOSTNAME=vega001 PARTITION=CPU)
eq "Vega CPU  MACHINE_NAME" "Vega (CPU)" "$(field "$d" MACHINE_NAME)"
eq "Vega CPU  GPU_VENDOR"   "none"       "$(field "$d" GPU_VENDOR)"

# Shared GPU Runner (NVIDIA)
d=$(detect HOSTNAME=runner-abc CI_RUNNER_TAGS=nvidia-cc80)
eq "Shared NVIDIA  MACHINE_NAME" "Shared GPU Runner (NVIDIA)" "$(field "$d" MACHINE_NAME)"
eq "Shared NVIDIA  GPU_NAME"     "A100"                        "$(field "$d" GPU_NAME)"

# Shared GPU Runner (AMD)
d=$(detect HOSTNAME=runner-abc CI_RUNNER_TAGS=amd-mi200)
eq "Shared AMD  MACHINE_NAME" "Shared GPU Runner (AMD)" "$(field "$d" MACHINE_NAME)"
eq "Shared AMD  GPU_NAME"     "MI210"                   "$(field "$d" GPU_NAME)"

# Shared Runner (plain — no GPU tags)
d=$(detect HOSTNAME=runner-abc)
eq "Shared plain  MACHINE_NAME" "Shared Runner" "$(field "$d" MACHINE_NAME)"
eq "Shared plain  GPU_VENDOR"   "none"          "$(field "$d" GPU_VENDOR)"

# ── Summary ──────────────────────────────────────────────────────────────────

printf '\n%d passed  %d failed\n' "$PASS" "$FAIL"
exit $((FAIL > 0 ? 1 : 0))
