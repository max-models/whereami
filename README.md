# `whereami` - a.k.a overengineered `module load`

But there are some important use cases for this, I promise!

This package detects the current HPC machine and exports environment variables describing it.
Comes with `load_modules`, a companion script that reads a `modules.json` file
and loads the right environment modules for the detected machine.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/max-models/whereami/main/install.sh | bash
```

Installs `whereami` and `load_modules` into `$HOME/.local/bin` (no sudo required).
If that directory is not yet on your `PATH`, add this to your shell config:

```bash
export PATH="${HOME}/.local/bin:${PATH}"
```

---

## `whereami`

Identifies the current HPC system, CPU, and GPU.

```bash
source whereami      # detect and export variables into the current shell
./whereami           # detect and print a summary table
whereami --help      # show usage
```

After sourcing, the following variables are available in your environment:

| Variable           | Example values                          |
|--------------------|-----------------------------------------|
| `MACHINE_NAME`     | `Raven`, `LUMI-G`, `Perlmutter`         |
| `MACHINE_HOST`     | `MPCDF`, `CSC`, `NERSC`                 |
| `CPU_VENDOR`       | `Intel`, `AMD`                          |
| `CHIP`             | `IceLake`, `Genoa`, `Milan`             |
| `GPU_VENDOR`       | `NVIDIA`, `AMD`, `none`                 |
| `GPU_NAME`         | `A100`, `MI250X`, `none`                |
| `GPUS_FOUND`       | `true`, `false`                         |
| `MACHINE_HOSTNAME` | system hostname                         |

---

## `load_modules`

Reads a `modules.json` file and loads the right modules for the detected machine.
Calls `whereami` automatically if the machine variables are not already set.

```bash
source load_modules                         # use modules.json in CWD, profile "default"
source load_modules gpu                     # profile "gpu"
source load_modules gpu intel               # tries "gpu_intel", falls back to "gpu", "default"
source load_modules /path/to/modules.json   # use a specific file, profile "default"
source load_modules /path/to/modules.json gpu  # specific file + profile
source load_modules -f /path/to/modules.json gpu  # same via -f flag
source load_modules --dry-run gpu           # print what would run, don't execute
source load_modules --verbose               # show which machine entry matched
load_modules --help                         # show usage
```

### `modules.json` format

The file uses a **machine-first** layout: machines are listed in order and the
first entry whose `match` fits the detected environment is used.  Within that
entry the requested profile (or the nearest fallback) is selected.

```json
{
  "schema_version": 3,
  "machines": [
    {
      "description": "Raven — Intel IceLake + NVIDIA A100",
      "match": { "machine_name": "Raven" },
      "profiles": {
        "default": {
          "modules_unload": ["gcc"],
          "modules_load":   ["intel/2024.1", "impi/2021.12", "hdf5-parallel/1.14"],
          "env":            { "OMP_NUM_THREADS": "18" }
        },
        "gpu": {
          "modules_unload": ["gcc"],
          "modules_load":   ["intel/2024.1", "impi/2021.12", "cuda/12.3", "hdf5-parallel/1.14"],
          "env":            { "OMP_NUM_THREADS": "18", "I_MPI_PIN": "1" }
        }
      }
    },
    {
      "description": "Generic fallback",
      "match": "default",
      "profiles": {
        "default": {
          "modules_load": ["gcc/13", "openmpi/4.1", "hdf5-parallel/1.14"]
        }
      }
    }
  ]
}
```

#### `match` field

| Value | Meaning |
|---|---|
| `"default"` | Always matches — use as last-resort fallback |
| `{ "machine_name": "Raven" }` | Matches when `MACHINE_NAME == "Raven"` |
| `{ "machine_host": "MPCDF", "cpu_vendor": "AMD" }` | All specified keys must match; omitted keys are wildcards |

Available keys: `machine_name`, `machine_host`, `cpu_vendor`, `chip`, `gpu_vendor`, `gpu_name`, `gpus_found`.

#### Profile fields

| Field | Type | Description |
|---|---|---|
| `modules_unload` | `string[]` | Modules to unload before loading |
| `modules_load` | `string[]` | Modules to load |
| `env` | `object` | Environment variables to export |

#### Profile fallback

If the requested profile is not defined in the matched machine, shorter prefixes
are tried before giving up:

```
gpu_intel  →  gpu  →  default
```

If the matched machine has none of the candidates, the search continues to the
next machine in the list.

A `modules.json` covering several machines is included in this repository as a
starting point — copy and adapt it for your own project.

---

## `edit_modules`

Interactively create or update a machine profile in `modules.json` for the
currently detected machine.

```bash
./edit_modules                          # edit "default" profile, modules.json in CWD
./edit_modules gpu                      # edit "gpu" profile
./edit_modules gpu intel                # edit "gpu_intel" profile
./edit_modules -f /path/to/modules.json # use a specific file
./edit_modules --dry-run gpu            # preview changes without writing
edit_modules --help                     # show usage
```

The script detects the current machine via `whereami`, then prompts you to
fill in (or update) the three profile fields:

| Prompt | What to type |
|---|---|
| `modules_unload` | space-separated list of modules to unload |
| `modules_load` | space-separated list of modules to load |
| `env` (one per existing var) | edit in place; clear the line to remove |
| `add env var` | `KEY=VALUE`, empty line to stop |

After all prompts a JSON preview is shown and you confirm before anything is
written.  The file is updated atomically (write to a temp file, then `mv`) so
a crash cannot corrupt it.

- If no entry exists for the detected machine a new one is inserted
  automatically, placed just before the generic `"default"` fallback.
- If the machine entry exists but the requested profile does not, the profile
  is added to the existing entry without touching other profiles.
- On **bash 4+** the current value is pre-filled in the readline buffer so
  you can edit it in place.  On bash 3.x (macOS default) the current value is
  shown in brackets and an empty reply keeps it unchanged.

---

## Acknowledgements

The template for this project is taken from the [confix tool](https://gitlab.mpcdf.mpg.de/phoenix-public/confix) used in [GENE-X](https://gitlab.mpcdf.mpg.de/phoenix-public/genex).
