---
title: whereami
description: Detect the HPC machine, CPU and GPU.
---

Identifies the current HPC system, CPU, and GPU.

```bash
source whereami      # detect and export variables into the current shell
./whereami           # detect and print a summary table
whereami --help      # show usage
```

To upgrade to the latest version, run:

```bash
whereami --update
```

This re-runs the installer against the directory `whereami` is installed in, so
`load_modules` and `edit_modules` are refreshed at the same time. It refuses to
run from a git checkout — use `git pull` there.

Use `-o`/`--output` to also save the detected parameters as JSON (parent
directories are created if needed):

```bash
whereami -o machine.json
```

```json
{
  "MACHINE_NAME": "Raven",
  "MACHINE_HOST": "MPCDF",
  "CPU_VENDOR": "Intel",
  "CHIP": "IceLake",
  "GPU_VENDOR": "NVIDIA",
  "GPU_NAME": "A100",
  "GPUS_FOUND": true,
  "MACHINE_HOSTNAME": "ravenlogin1"
}
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
