# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.9.2] — 2026-07-02

### Fixes

- **Waybar removal array-agnostic (#10)**: `waybar-remove` (and `setup --force`) only scrubbed `modules-right`. A module placed in `modules-left` or `modules-center` was orphaned on uninstall — definition removed, placement left behind, resulting in a broken module reference. Removal now matches any `modules-*` array (sibling-safe sed), mirroring the array-agnostic detection introduced in #7. Drops the now-dead `_in_modules_right` / `_get_modules_right_block` helpers. Thanks @Mahlski.
- **Waybar reload via SIGUSR2 (#11)**: `_restart_waybar` used `pkill -x waybar` + `sleep 0.5` + `hyprctl dispatch exec waybar`. On Lua-config Hyprland, `hyprctl dispatch` is blocked — waybar was killed but never relaunched, leaving the bar dead until a manual restart. Replaced with `pkill -SIGUSR2 -x waybar` (waybar's documented in-place reload signal). PID stays intact, no hardcoded UID/`WAYLAND_DISPLAY`/instance-signature assumptions, both scripts shellcheck-clean. Thanks @Mahlski.

## [0.9.1] — 2026-06-27

### Fixes

- **Waybar auto-integration (#7)**: `waybar-setup` only checked `modules-right`, so a module placed in `modules-left` or `modules-center` was not detected and got duplicated into `modules-right` on every `hyprcaffeine setup` run (e.g. `post_upgrade`). It now detects the module as an array element in any `modules-*` array and skips positioning when already present. Thanks @Mahlski.

## [0.9.0] — 2026-06-24

### Fixes

- **Config-driven menu presets (#6)**: The interactive menu now honors `timeouts.presets` from the user config instead of hardcoded durations. Removing or customizing a preset (e.g. the default 15 min) now takes effect in both `caffeine-menu.sh` and `ui-engine.sh`.
- **No blank trailing menu option (#5)**: Menu rendering switched from `echo -e` to `printf '%s\n'`, removing the spurious blank option at the end of the list in walker/wofi/rofi (caused by a trailing empty line that the old strip pattern failed to remove).
- **Lua keybind detection (#4)**: Keybind format is now chosen by which Hyprland config the user has on disk (`hyprland.lua` vs `hyprland.conf`), not by the Hyprland version. Fixes keybindings silently failing for `hyprland.conf` users on Hyprland ≥0.55, who were wrongly switched to the Lua path.
- **Installer**: keybind-install stderr is no longer suppressed, so format/source errors surface instead of failing silently.

---

## [0.8.5] — 2026-05-29

### Added

- **Interactive menus**: Add `rofi` as a supported fallback for interactive menus (selection and custom-duration input). `wofi` remains supported on Wayland; `gum` is still used for TUI-style menus.

---

## [0.8.4] — 2026-05-26

### Fixes

- **Setup (polkit)**: `do_setup()` no longer attempts to read or verify the polkit rule file from user context. `/etc/polkit-1/rules.d/` is `0750 root:polkitd` — non-root users cannot stat files inside it, so `-f` always returned false, causing a spurious "Not found or outdated → reinstalling" path that then failed with `sudo` requiring a TTY. The user-context branch now skips validation entirely and prints guidance to run `sudo hyprcaffeine polkit install` if needed.

### Added

- **Interactive menus**: Add `rofi` as a supported fallback for interactive menus (selection and custom-duration input). `wofi` remains supported on Wayland; `gum` is still used for TUI-style menus.

---

## [0.8.3] — 2026-05-25

### Fixes

- **Setup (polkit)**: `do_setup()` now verifies polkit rule content before attempting reinstall. Previously it tried `sudo` unconditionally which failed in `runuser` context (no TTY). Now checks if the rule file exists AND contains valid inhibit action IDs — only reinstalls if missing or invalid.

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
