---
title: edit_modules
description: Create or update a machine profile interactively.
---

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
