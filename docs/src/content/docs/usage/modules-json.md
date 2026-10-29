---
title: modules.json
description: The machine-first format of modules.json.
---

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

## `match` field

| Value | Meaning |
|---|---|
| `"default"` | Always matches — use as last-resort fallback |
| `{ "machine_name": "Raven" }` | Matches when `MACHINE_NAME == "Raven"` |
| `{ "machine_host": "MPCDF", "cpu_vendor": "AMD" }` | All specified keys must match; omitted keys are wildcards |

Available keys: `machine_name`, `machine_host`, `cpu_vendor`, `chip`, `gpu_vendor`, `gpu_name`, `gpus_found`.

## Profile fields

| Field | Type | Description |
|---|---|---|
| `modules_unload` | `string[]` | Modules to unload before loading |
| `modules_load` | `string[]` | Modules to load |
| `env` | `object` | Environment variables to export |

## Profile fallback

If the requested profile is not defined in the matched machine, shorter prefixes
are tried before giving up:

```
gpu_intel  →  gpu  →  default
```

If the matched machine has none of the candidates, the search continues to the
next machine in the list.

A `modules.json` covering several machines is included in this repository as a
starting point — copy and adapt it for your own project.
