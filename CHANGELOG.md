# Changelog

All notable changes to HyprCaffeine are documented here.

## v0.7.4 (2025-05-20)

### ✨ New Features
- **Keybinding system** — `hyprcaffeine keybinds install|remove|status` subcommand. Auto-generates Hyprland keybinds with version-aware format (Hyprlang for <0.55, Lua for ≥0.55).
- **Desktop notifications** — `notify-send` alerts when monitor keep-awake or lid inhibit are toggled on/off.
- **Walker menu enhancements** — Improved Catppuccin Mocha theme with descriptive icons, better spacing, and green accent border.
- **Automatic keybind installation** — Post-install script now runs `hyprcaffeine keybinds install`.

### 🔧 Changed
- **Path resolution** — Keybinds use absolute binary path (`/home/*/.local/bin/hyprcaffeine`) to avoid Hyprland PATH issues.
- **Monitor/Lid** — Now send `notify-send` on every toggle (enabled/disabled).
- **Post-install** — Delegates waybar setup and keybinds to CLI subcommands.

### 🐛 Fixed
- Keybinds not working on systems without `$mainMod` defined (now uses `SUPER` directly).
- Dead keybind (SUPER+CTRL+I) conflict with Omarchy's `bindd` — **auto-commented on install** (v0.7.4-2).
- Omarchy binds auto-restored on `hyprcaffeine keybinds remove` (v0.7.4-2).

### 📦 Packaging
- PKGBUILD v0.7.4-1 → v0.7.4-2 (Omarchy conflict fix, commit-based source archive).

---

## v0.7.3 (2025-05-17)

### 🐛 Fixed
- Waybar CSS detection — now checks for actual `#custom-hyprcaffeine` content instead of comment markers during cleanup.
- Waybar module positioning — smart insert in `modules-right` after `group/trap-expander`.

### 📦 Packaging
- Removed PGP signature from PKGBUILD (eliminates yay's `--skippgpcheck` warning).

---

## v0.7.2 (2025-05-16)

### 🐛 Fixed
- `.SRCINFO` depends format — one value per line to fix "No AUR package found" error.
- `sha256sums` syntax in PKGBUILD.

---

## v0.7.1 (2025-05-16)

### 🐛 Fixed
- Waybar-setup/remove — use Python3 for reliable JSON parsing, scoped sed for `modules-right`.

### 📦 Packaging
- Sha256sums updated.

---

## v0.7.0 (2025-05-16)

### ✨ New Features
- `hyprcaffeine waybar-setup` and `hyprcaffeine waybar-remove` CLI commands for waybar integration management.
- Smart post-install — auto-detects user, installs polkit rules, sets up waybar and systemd.

---

## v0.6.5 (2025-05-16)

### 🔧 Changed
- Timer system rewritten for reliability.
- State file format v2 with JSON structure.

---

## v0.6.4

### 🔧 Changed
- Performance improvements to the watcher loop.
