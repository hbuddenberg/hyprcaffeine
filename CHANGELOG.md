# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.8.2] — 2026-05-26

### Fixes

- **Setup (polkit)**: `do_setup()` now always reinstalls the polkit rule instead of skipping when the file already exists. Previously, if the rule was present (even with stale/incorrect content), setup would report "Already installed" and skip — potentially leaving broken sleep/lid inhibition. The rule is now unconditionally overwritten on every `hyprcaffeine setup` and `post_upgrade` run.

---

## [0.8.0-3] — 2026-05-25

### Fixes

- **Restore (boot)**: `do_restore` now waits up to 60 s for the Hyprland IPC socket before creating inhibitors. On non-UWSM systems `default.target` fires before Hyprland starts; the wait guarantees inhibitors are registered into an active session.
- **Restore (boot)**: Finite timers are no longer restored on reboot — they are ephemeral and non-persistent. The stale `active` state is cleared to `inactive` so the UI starts clean. Only monitor keep-awake, lid-close inhibit, and infinite idle mode are restored.
- **Systemd service**: Add `TimeoutStartSec=120` to accommodate the 60 s socket-wait inside `restore`.

---

## [0.8.0] — 2026-05-22

### Fixes

- **Installer (.install)**: Replace `su -` with `runuser -l` for user-context post-install steps, ensuring reliable execution in pacman hook environment (no TTY).
- **Installer (.install)**: Remove `2>/dev/null` from `polkit-setup.sh` call in `post_install` hook so failures are visible instead of silent.
- **polkit-setup.sh**: Add `mkdir -p` for the rules directory before writing the rule file.
- **setup subcommand**: Remove `2>/dev/null` suppression from `do_polkit_install` call so errors surface to the user.
- **post-install.sh**: Remove dead `hyprcaffeine polkit install` call (subcommand does not exist); polkit rule is correctly installed in the root context by the pacman `.install` hook.
- **Version**: Bump binary `VERSION` to `0.8.0`.

---

## [0.7.8] — 2026-05-21

### Fixes

- **Watcher**: Resolve socket path dynamically and scan runtime directories (e.g. for newer Hyprland versions v0.54.x+ that don't use `/tmp/hypr/.hyprland_instances`).
- **Watcher**: Tolerate missing socket at startup and retry connecting in the background, preventing daemon startup pre-flight failure.
- **Systemd**: Tolerate watcher-start failure in oneshot systemd user unit to prevent systemd from killing the restored inhibitors cgroup at boot.
- **Installer**: Make polkit installation failure non-fatal to allow user-local installs to complete successfully.
- **Installer**: Add keybinding setup step so Hyprland keybindings are configured automatically during installation.
- Use `-H` instead of `-h` for wofi menu height (`-h` is `--help` in wofi) to prevent printing help text and toggling monitor state.

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
