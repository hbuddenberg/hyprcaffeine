# Changelog

Todos los cambios notables de este proyecto se documentan aquí.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

---

## [0.7.7] — 2026-05-21

### ⚠️ Cambios rotundos

- **Polkit rule obligatoria** — la instalación aborta si la regla polkit no se puede escribir
- **Polkit rule siempre se sobreescribe** — no existe skip, no existe "ya existe", siempre se instala
- **`hypridle` como dependencia requerida** en PKGBUILD

### Correcciones

- Pantalla se apagaba durante inhibit: `hypridle` no estaba corriendo
- Polkit rule no se instalaba: era condicional (`if [ ! -f ... ]`), ahora siempre se instala
- `hyprcaffeine.install` (`post_install`): removido check de existencia — siempre overwrites
- `install.sh`: si polkit falla → `return 1` con instrucciones claras para instalación manual
- `install.sh`: fallback a generación inline de polkit rule si no hay template disponible
- `install.sh`: múltiples approaches de `sudo` (`tee` + `cp`) para mayor compatibilidad
- `install.sh`: verificación de runtime dependency `hypridle` (warn si no está)

### Tests

- 55/55 tests unitarios PASS
- 7/7 tests funcionales PASS (NUC + ASUS)
  - `on infinite` → inhibit SLEEP
  - `monitor on` → inhibit IDLE
  - `lid on` → inhibit HANDLE-LID-SWITCH
  - `off` → preserva monitor + lid
  - `on 5m` (timer) → countdown correcto
  - `off --all` → todo limpio

---

## [0.7.6] — 2026-05-20

### Añadido

- Sistema de keybinds para Hyprland (toggle rápido por teclado)
- Persistencia en segundo plano (monitor/lid sobreviven cerrar la app)
- Tests de diagnóstico (`tests/test-inhibit.sh`)

### Correcciones

- Manejo de errores en inhibit — ya no falla silenciosamente
- Polkit always-copy — la regla se copia correctamente desde el template

---

## [0.7.5] — 2026-05-18

### Correcciones

- Revert a v0.7.4 por inestabilidad en keybinds

---

## [0.7.4] — 2026-05-17

### Añadido

- Countdown timer con notificaciones de escritorio
- Integración con Walker menu
- Servicio systemd para auto-start del watcher

---

## [0.7.3] — 2026-05-15

### Añadido

- Integración Waybar con CSS classes (Catppuccin Mocha)
- Comando `waybar` para output JSON compatible
- Soporte para `monitor on/off` y `lid on/off`

---

## [0.7.2] — 2026-05-12

### Añadido

- Comando `toggle` para activar/desactivar rápidamente
- Comando `status` con iconos Nerd Font
- Soporte para duraciones (`on 30m`, `on 2h`, `on infinite`)

---

## [0.7.1] — 2026-05-10

### Correcciones

- Fix: inhibits no se limpiaban al apagar timer
- Fix: state file se corrompía con llamadas concurrentes

---

## [0.7.0] — 2026-05-08

### Añadido

- Versión inicial pública
- Inhibición de sleep/suspend vía `systemd-inhibit`
- Inhibición de monitor (DPMS/dim)
- Inhibición de lid-close
- Instalador interactivo con `gum`
- PKGBUILD para AUR
