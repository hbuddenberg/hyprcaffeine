# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.7.8] — 2026-05-21

### Fixes

- Use `-H` instead of `-h` for wofi menu height (`-h` is `--help` in wofi)
- Prevents wofi from printing help text and accidentally toggling monitor caffeine state

---

## [0.7.7] — 2026-05-21

### ⚠️ Breaking Changes

- **Polkit rule is now mandatory** — installation aborts if the polkit rule cannot be written
- **Polkit rule always overwrites** — no skip, no "already exists" check, always installs
- **`hypridle` added as required dependency** in PKGBUILD

### Fixes

- Screen turning off during inhibit: `hypridle` was not running
- Polkit rule not installed: was conditional (`if [ ! -f ... ]`), now always installs
- `hyprcaffeine.install` (`post_install`): removed existence check — always overwrites
- `install.sh`: if polkit fails → `return 1` with clear manual install instructions
- `install.sh`: inline generation fallback when no template is available
- `install.sh`: multiple `sudo` approaches (`tee` + `cp`) for broader compatibility
- `install.sh`: `hypridle` runtime dependency check (warns if missing)

### Tests

- 55/55 unit tests PASS
- 7/7 functional tests PASS (NUC + ASUS)
  - `on infinite` → inhibit SLEEP
  - `monitor on` → inhibit IDLE
  - `lid on` → inhibit HANDLE-LID-SWITCH
  - `off` → preserves monitor + lid
  - `on 5m` (timer) → countdown correct
  - `off --all` → everything clean

---

## [0.7.6] — 2026-05-20

### Added

- Hyprland keybind system (quick toggle via keyboard)
- Background persistence (monitor/lid survive app close)
- Diagnostic tests (`tests/test-inhibit.sh`)

### Fixes

- Inhibit error handling — no longer fails silently
- Polkit always-copy — rule copies correctly from template

---

## [0.7.5] — 2026-05-18

### Fixes

- Reverted to v0.7.4 due to keybind instability

---

## [0.7.4] — 2026-05-17

### Added

- Countdown timer with desktop notifications
- Walker menu integration
- Systemd service for watcher auto-start

---

## [0.7.3] — 2026-05-15

### Added

- Waybar integration with CSS classes (Catppuccin Mocha)
- `waybar` command for compatible JSON output
- `monitor on/off` and `lid on/off` support

---

## [0.7.2] — 2026-05-12

### Added

- `toggle` command for quick on/off
- `status` command with Nerd Font icons
- Duration support (`on 30m`, `on 2h`, `on infinite`)

---

## [0.7.1] — 2026-05-10

### Fixes

- Inhibits not cleaned up when timer expires
- State file corruption on concurrent calls

---

## [0.7.0] — 2026-05-08

### Added

- Initial public release
- Sleep/suspend inhibition via `systemd-inhibit`
- Monitor inhibition (DPMS/dim)
- Lid-close inhibition
- Interactive installer with `gum`
- PKGBUILD for AUR
