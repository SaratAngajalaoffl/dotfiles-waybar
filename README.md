# dotfiles-waybar

Config for [waybar](https://github.com/Alexays/Waybar) (the status bar), theme-integrated via the `theme` submodule.

Part of the [dotfiles-arch](https://github.com/SaratAngajalaoffl/dotfiles-arch) multi-repo dotfiles system.

## Layout

- `config` → `~/.config/waybar` (see `.links`)
- `config/colors.css` is gitignored — it's a symlink to the active theme's colors, not tracked content (see the `theme` submodule)

## Setup

Not used standalone — applied by the parent repo's `install.sh`, which reads `.links` and symlinks `config` into place.
