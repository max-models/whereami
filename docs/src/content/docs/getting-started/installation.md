---
title: Installation
description: Install whereami, load_modules and edit_modules.
---

```bash
curl -fsSL https://raw.githubusercontent.com/max-models/whereami/main/install.sh | bash
```

Installs `whereami` and `load_modules` into `$HOME/.local/bin` (no sudo required).
If that directory is not yet on your `PATH`, the installer adds it to your shell
startup file (`~/.zshrc`, `~/.bashrc`, `~/.config/fish/config.fish`, ...) — open
a new terminal afterwards to pick it up.

To keep your startup files untouched and just be told what to add, pass
`--no-modify-path` (or set `WHEREAMI_NO_MODIFY_PATH=1`):

```bash
curl -fsSL https://raw.githubusercontent.com/max-models/whereami/main/install.sh | bash -s -- --no-modify-path
```

To install somewhere else, pass the target directory as an argument (or set
`WHEREAMI_INSTALL_DIR`):

```bash
curl -fsSL https://raw.githubusercontent.com/max-models/whereami/main/install.sh | bash -s -- /opt/bin
```
