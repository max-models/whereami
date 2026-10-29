---
title: load_modules
description: Load the modules of the detected machine.
---

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

The file format is described in [modules.json](/whereami/usage/modules-json/).
