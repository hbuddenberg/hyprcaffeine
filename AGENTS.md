# HyprCaffeine — Agent Guide

> **Documento para agentes de IA.** Explica la arquitectura, funcionalidades, flujo de desarrollo y decisiones de diseño del proyecto.
> Creado para que cualquier agente (humano o IA) pueda entender, mantener y extender HyprCaffeine.

---

## 📋 Tabla de Contenidos

1. [¿Qué es HyprCaffeine?](#qué-es-hyprcaffeine)
2. [Arquitectura](#arquitectura)
3. [Funcionalidades](#funcionalidades)
4. [Sistema de Keybinds](#sistema-de-keybinds)
5. [Walker Menu — UI Visual](#walker-menu--ui-visual)
6. [Waybar Module](#waybar-module)
7. [Estado y Persistencia](#estado-y-persistencia)
8. [Notificaciones](#notificaciones)
9. [Flujo de Desarrollo y Release](#flujo-de-desarrollo-y-release)
10. [AUR Packaging](#aur-packaging)
11. [Decisiones de Diseño](#decisiones-de-diseño)
12. [Pitfalls Conocidos](#pitfalls-conocidos)
13. [Diagrama de Flujo](#diagrama-de-flujo)

---

## ¿Qué es HyprCaffeine?

HyprCaffeine es un utility de **idle inhibition** para [Hyprland](https://github.com/hyprwm/Hyprland). Permite:

- Evitar que la pantalla se apague/dimmee (modo monitor)
- Evitar que el sistema suspenda al cerrar la tapa (modo lid)
- Bloquear el suspend por N minutos o indefinidamente (modo timer/infinite)
- Controlar todo desde un menú visual (Walker), la barra (Waybar), atajos de teclado, o CLI

**Stack:** Bash script puro + jq (JSON) + Hyprland IPC + Walker (GTK4) + Waybar

---

## Arquitectura

```
hyprcaffeine/
├── bin/
│   └── hyprcaffeine          ← Entry point CLI (bash script, ~19KB)
├── scripts/
│   ├── caffeine-menu.sh      ← Menú Walker (GTK4 launcher)
│   ├── config.sh             ← Config parser (YAML-like)
│   ├── hyprland.sh           ← Hyprland IPC (sockets, inhibir idle)
│   ├── icons.sh              ← Iconos unicode/nerd font
│   ├── keybinds.sh           ← Generación/gestión de keybinds Hyprland
│   ├── notify.sh             ← Notificaciones desktop
│   ├── post-install.sh       ← Post-instalación (waybar, systemd, keybinds)
│   ├── state.sh              ← Manejo de estado persistente (JSON)
│   ├── timer.sh              ← Timer para duraciones finitas
│   ├── ui-engine.sh          ← Motor de UI interactiva (gum)
│   ├── watcher.sh            ← Daemon de auto-detección (fullscreen, audio, etc.)
│   ├── waybar.sh             ← Generador de JSON para Waybar
│   ├── waybar-setup.sh       ← Instalación inteligente en waybar config
│   └── waybar-remove.sh      ← Remoción de waybar config
├── config/
│   └── default.yaml          ← Configuración por defecto del usuario
├── systemd/
│   └── hyprcaffeine.service  ← Servicio systemd user
├── waybar/
│   ├── module.json           ← Template del módulo waybar
│   └── waybar-css.css        ← CSS del módulo waybar
├── docs/
│   ├── CONFIG.md
│   ├── INSTALL.md
│   └── WAYBAR.md
├── assets/
├── themes/
├── PKGBUILD                  ← Arch AUR
├── .SRCINFO                  ← Metadatos AUR
├── hyprcaffeine.install      ← Script post-install de pacman
├── install.sh                ← Instalación manual (local)
├── CHANGELOG.md
└── README.md
```

### Flujo de ejecución

```
Usuario escribe: hyprcaffeine on 30m
       │
       ▼
 bin/hyprcaffeine  ← parser de argumentos
       │
       ├──► scripts/config.sh    ← Lee ~/.config/hyprcaffeine/config.yaml
       ├──► scripts/state.sh     ← Lee/escribe ~/.cache/hyprcaffeine/state.json
       ├──► scripts/hyprland.sh  ← Hyprland IPC (inhibir idle vía dbus/socket)
       ├──► scripts/timer.sh     ← Programa timer con sleep + notify
       └──► scripts/notify.sh    ← notify-send
```

---

## Funcionalidades

### 1. Timer / Infinite Mode
```bash
hyprcaffeine on          # 30 min (default)
hyprcaffeine on 2h       # 2 horas
hyprcaffeine on infinite # Indefinido
hyprcaffeine off         # Apagar
hyprcaffeine toggle      # Toggle infinite
```

**Cómo funciona:**
- Crea un archivo `idle_inhibit.pid` en `~/.cache/hyprcaffeine/`
- Usa `hyprctl` para inhibir el idle de Hyprland (`hyprctl setcursor` + inhibir vía dbus)
- Si tiene duración finita, lanza un timer en background con `sleep` + `notify-send` al expirar
- State: `{"status":"active","duration":1800,"activated_at":"2025-05-20T10:00:00"}`

### 2. Monitor Keep-Awake
```bash
hyprcaffeine monitor on     # Evita dimming/DPMS/lock
hyprcaffeine monitor off    # Restaura comportamiento normal
hyprcaffeine monitor toggle # Toggle
```

**Cómo funciona:**
- Usa `hyprctl keyword dpms` y manipula `misc:disable_autoreload`
- Independiente del timer — se puede tener monitor ON sin idle inhibition
- Persistente: el estado se guarda en `state.json` y se restaura al iniciar el servicio

### 3. Lid Inhibit
```bash
hyprcaffeine lid on         # Bloquea suspender al cerrar tapa
hyprcaffeine lid off        # Restaura
hyprcaffeine lid toggle
```

**Cómo funciona:**
- Usa `systemd-inhibit` o manipula `handle_lid_switch` en Hyprland
- Requiere polkit para ciertas operaciones
- Independiente de monitor y timer — cada toggle es independiente

### 4. Walker Menu
```bash
hyprcaffeine menu           # Abre menú visual con Walker
```

Ver sección [Walker Menu](#walker-menu--ui-visual).

### 5. Waybar Module
```bash
hyprcaffeine waybar          # Output JSON para waybar
hyprcaffeine waybar-setup    # Instalación automática
hyprcaffeine waybar-setup --force  # Recrear desde cero
hyprcaffeine waybar-remove   # Remover
```

Ver sección [Waybar Module](#waybar-module).

### 6. Keybinds
```bash
hyprcaffeine keybinds install   # Instalar atajos Hyprland
hyprcaffeine keybinds remove    # Remover
hyprcaffeine keybinds status    # Ver estado
```

Ver sección [Sistema de Keybinds](#sistema-de-keybinds).

### 7. Watcher Daemon
```bash
hyprcaffeine watcher start    # Inicia daemon de auto-detección
hyprcaffeine watcher stop     # Detiene
hyprcaffeine watcher status   # Estado
```

Detecta automáticamente:
- Apps en fullscreen → activa caffeine temporalmente
- Reproducción de audio → evita suspend
- Procesos personalizados (Steam, Discord) configurados en `config.yaml`

---

## Sistema de Keybinds

### Atajos por defecto

| Combinación | Acción | Modmask |
|---|---|---|
| `SUPER + CTRL + I` | Toggle infinite idle | 68 |
| `SUPER + CTRL + SHIFT + I` | Mostrar menú Walker | 69 |
| `SUPER + CTRL + SHIFT + D` | Toggle lid inhibit | 69 |
| `SUPER + CTRL + D` | Toggle monitor keep-awake | 68 |

### Cómo funciona

El archivo `scripts/keybinds.sh` es el motor:

1. **Detección de versión de Hyprland:** Detecta si es < 0.55 (Hyprlang) o ≥ 0.55 (Lua)
2. **Generación de binds:** Crea archivo en `~/.config/hypr/hyprcaffeine-keybinds.conf` (o `.lua`)
3. **Source en `hyprland.conf`:** Agrega `source = ~/.config/hypr/hyprcaffeine-keybinds.conf` AL FINAL del archivo (para prioridad)
4. **Resolución de conflictos:** Busca binds duplicados en configuraciones de Omarchy y los comenta
5. **Rutas absolutas:** Usa `command -v hyprcaffeine` para obtener el path completo (evita problemas de PATH en Hyprland)

### Orden de ejecución crítica

```
keybinds install:
  1. Resolver conflictos Omarchy    ← SIEMPRE primero
  2. Verificar up-to-date            ← Puede return early
  3. Generar archivo de binds
  4. Agregar source a hyprland.conf
  5. hyprctl reload

keybinds remove:
  1. Eliminar archivo de binds
  2. Remover source line de hyprland.conf
  3. Restaurar binds de Omarchy que fueron comentados
  4. hyprctl reload
```

### Resolución de conflictos con Omarchy

```bash
# Busca en estos archivos:
~/.local/share/omarchy/default/hypr/bindings/*.conf
~/.local/share/omarchy/config/hypr/bindings.conf
~/.local/share/omarchy/config/hypr/hyprland.conf

# Patrón de búsqueda (CRÍTICO: usar coma final):
grep -n "bind.*SUPER CTRL, D," utilities.conf  # ✅
grep -n "bind.*SUPER CTRL, D" utilities.conf    # ❌ matchea "Delete"

# Acción: comenta la línea encontrada
sed -i '31s/^/# /' utilities.conf
```

> **⚠️ CRÍTICO:** Siempre usar coma final en el patrón grep para evitar falsos positivos con teclas como `SUPER CTRL, D` vs `SUPER CTRL, Delete`.

---

## Walker Menu — UI Visual

### Tema Catppuccin Mocha

El menú Walker usa un tema personalizado en:

```
~/.config/walker/themes/caffeine/style.css
```

**Estructura del tema:** Debe ser un **directorio** `themes/<name>/style.css`, NO un archivo suelto.

**Config:** `~/.config/walker/config.toml` con `theme = "caffeine"` al nivel raíz (NO bajo `[ui]`).

**Selectores CSS usados (GTK4 reales de Walker):**

```css
#window                → Ventana principal
#search                → Input de búsqueda  
#scroll                → Contenedor scrolleable
#item                  → Cada item del menú
#text                  → Texto del item
#sub                   → Subtítulo
#activationlabel       → Label de activación
#provider              → Proveedor (label sección)
```

### Estilo visual

```
┌─────────────────────────────────────┐
│  Caffeine          (header verde)   │
│                                     │
│  ○   Timer Mode                     │
│  ○   Infinite Mode                  │
│  ●   Pantalla ON     ← toggle activo│
│  ○   Tapa                           │
│                                     │
│  ⏱  15 min   30 min   1h    2h     │
│                                     │
│  ❌  Disable Caffeine               │
└─────────────────────────────────────┘
  Borde: 2px solid #a6e3a1 (verde)
  Fondo: #11111b (Catppuccin Mocha base)
  Texto: #cdd6f4
  Radio: 14px
```

**Paleta Catppuccin Mocha:**
- `#11111b` — Base (bg ventana)
- `#1e1e2e` — Mantle (bg items)
- `#313244` — Surface0 (hover)
- `#cdd6f4` — Texto
- `#a6e3a1` — Verde (accent, header)
- `#f38ba8` — Rojo (disable)
- `#fab387` — Naranja (warnings)

---

## Waybar Module

### Output JSON

```json
{
  "text": "☕ 30m",
  "class": "active",
  "tooltip": "Caffeine: active\n30 min remaining\nMonitor: ON\nLid: OFF"
}
```

### Clases CSS

```css
#custom-hyprcaffeine           /* Inactivo — gris */
#custom-hyprcaffeine.active    /* Timer o infinite — naranja/verde */
#custom-hyprcaffeine.monitor   /* Monitor keep-awake activo */
#custom-hyprcaffeine.lid       /* Lid inhibit activo */
```

### Posicionamiento (crítico)

El módulo debe ir en `modules-right` **después** de `group/tray-expander`, como **sibling** (NO dentro del grupo):

```jsonc
// ✅ CORRECTO
"modules-right": [
  "group/tray-expander",
  "custom/hyprcaffeine",     // ← sibling, no dentro del grupo
  "clock"
]

// ❌ INCORRECTO — dentro del grupo
"modules-right": [
  {
    "group/tray-expander": {
      "modules": ["hyprcaffeine"]  // ← NO
    }
  }
]
```

### Detección de instalación

Para verificar si waybar ya tiene el módulo, chequear contenido REAL, no comentarios:

```bash
# ✅ CORRECTO — busca contenido real
grep -q '#custom-hyprcaffeine' style.css

# ❌ INCORRECTO — busca marcador (sobrevive a limpieza parcial)
grep -q 'HyprCaffeine' style.css
```

---

## Estado y Persistencia

### state.json

```json
{
  "status": "active",
  "duration": 1800,
  "activated_at": "2025-05-20T10:00:00",
  "pid": 12345,
  "monitor": true,
  "lid": false
}
```

Ubicación: `~/.cache/hyprcaffeine/state.json`

**Campos:**
- `status`: `"active"` | `"inactive"`
- `duration`: segundos (0 = infinite)
- `activated_at`: ISO timestamp
- `pid`: PID del proceso timer
- `monitor`: `true` si monitor keep-awake está activo
- `lid`: `true` si lid inhibit está activo

### Archivos adicionales en cache

```
~/.cache/hyprcaffeine/
├── state.json            ← Estado principal
├── idle_inhibit.pid      ← PID del inhibit
├── timer.pid             ← PID del timer sleep
├── timer.log             ← Log del timer
└── watcher.log           ← Log del watcher daemon
```

### Configuración de usuario

`~/.config/hyprcaffeine/config.yaml` — auto-creado desde `config/default.yaml`:

```yaml
keybinds:
  enabled: true
  toggle_infinite: "$mainMod CTRL, I"

timeouts:
  default: 1800
  presets: [900, 1800, 3600, 7200]

notifications:
  enabled: true
  expire_warning: 60

features:
  monitor: false
  lid: false
```

---

## Notificaciones

Cada acción de toggle envía `notify-send`:

| Acción | Notificación |
|---|---|
| `monitor on` | 🖥 Monitor — Keep display on: enabled |
| `monitor off` | 🖥 Monitor — Keep display on: disabled |
| `lid on` | 💻 Lid — Lid-close inhibit: enabled |
| `lid off` | 💻 Lid — Lid-close inhibit: disabled |
| `on <duration>` | ☕ Caffeine: active (30m) |
| `timer expired` | ☕ Caffeine expired |

Dependencia: `libnotify` (optdep en PKGBUILD).

---

## Flujo de Desarrollo y Release

### Workflow completo

```
1. Desarrollo en master (NUC)
       │
2. git commit + push
       │
3. git tag vX.Y.Z
       │
4. gh release create vX.Y.Z --notes-file /tmp/notes.md
       │
5. Esperar 10-30s (CDN propagation)
       │
6. Calcular sha256 desde MÁQUINA TARGET (ASUS)
       │
7. Descargar tarball desde ASUS → subir como release asset
       │
8. gh release upload vX.Y.Z /path/to/tarball --clobber
       │
9. Actualizar PKGBUILD con sha256 de ASUS + source = release asset
       │
10. Commit + push (sin retag)
       │
11. AUR: clone → copy PKGBUILD + .install → regen .SRCINFO → push
       │
12. TEST en máquina target: yay -S hyprcaffeine
```

### Reglas de oro

- **🚫 NUNCA retag.** Si hay bug post-release, bump pkgrel (1→2) o version (v0.7.4→v0.7.5)
- **✅ gh release --notes-file** — nunca `--notes "..."` (se corta)
- **✅ sha256 desde máquina target** — no desde dev (CDN inconsistency)
- **✅ Release assets estáticos** — no archive URLs (CDN inconsistency)
- **✅ pkgrel bump** para fixes post-release (no nuevo tag)
- **✅ Test en target ANTES de considerar el release completo**

### Post-release fix flow

Si se descubre un bug inmediatamente después del release:

```bash
# 1. Fix en master
git add -A && git commit -m "fix: descripción"
git push origin master

# 2. Obtener nuevo commit SHA
git rev-parse HEAD

# 3. Descargar tarball desde target machine
ssh target 'curl -sL -o /tmp/pkg.tar.gz https://github.com/.../archive/<SHA>.tar.gz'

# 4. Subir como release asset (reemplaza el anterior)
gh release upload vX.Y.Z /tmp/pkg.tar.gz --clobber

# 5. Calcular sha256 en target
ssh target 'sha256sum /tmp/pkg.tar.gz'

# 6. Actualizar PKGBUILD
#    - pkgrel += 1 (e.g., 1 → 2)
#    - source apunta a release asset
#    - sha256 = valor de target

# 7. Commit PKGBUILD + push (NO retag)

# 8. AUR: clone → copy → .SRCINFO → push
```

---

## AUR Packaging

### PKGBUILD (v0.7.4-2 template)

```bash
# Maintainer: Hans-Dieter Buddenberg <hbuddenberg@gmail.com>
pkgname=hyprcaffeine
pkgver=0.7.4
pkgrel=2
pkgdesc='☕ Idle inhibition utility for Hyprland'
arch=(any)
url='https://github.com/hbuddenberg/hyprcaffeine'
license=(MIT)
depends=(bash jq hyprland socat)
optdepends=(
    'gum: interactive menu'
    'libnotify: desktop notifications'
    'walker: menu frontend'
)
install=hyprcaffeine.install
source=("$pkgname-$pkgver.tar.gz::$url/releases/download/v$pkgver/hyprcaffeine-$pkgver.tar.gz")
sha256sums=('CALCULATED_FROM_TARGET')

prepare() {
    cd "$(find "$srcdir" -maxdepth 1 -type d -name 'hyprcaffeine*' | head -1)" || return
    sed -i "s|LIB_DIR=\"\${SCRIPT_DIR}/../scripts\"|LIB_DIR=\"/usr/share/hyprcaffeine/scripts\"|" bin/hyprcaffeine
}

package() {
    cd "$(find "$srcdir" -maxdepth 1 -type d -name 'hyprcaffeine*' | head -1)" || return
    install -Dm755 bin/hyprcaffeine "${pkgdir}/usr/bin/hyprcaffeine"
    install -dm755 "${pkgdir}/usr/share/hyprcaffeine/scripts"
    install -Dm755 scripts/*.sh "${pkgdir}/usr/share/hyprcaffeine/scripts/"
    install -Dm644 config/default.yaml "${pkgdir}/usr/share/hyprcaffeine/config/default.yaml"
    install -Dm644 systemd/hyprcaffeine.service "${pkgdir}/usr/share/hyprcaffeine/systemd/"
    install -Dm644 README.md "${pkgdir}/usr/share/doc/hyprcaffeine/"
    install -Dm644 docs/*.md "${pkgdir}/usr/share/doc/hyprcaffeine/"
    install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/$pkgname/LICENSE"
}
```

### .SRCINFO — Una dependencia por línea

```bash
depends = bash
depends = jq
depends = hyprland
# ❌ NO: depends = bash jq hyprland
```

### hyprcaffeine.install (post-install de pacman)

```bash
post_install() {
    _user=""
    for d in /home/*; do
        [ -d "$d/.config/waybar" ] && [ -d "$d/.config/hypr" ] && _user="$(basename "$d")" && break
    done
    [ -z "$_user" ] && return 0
    
    # Polkit (root)
    sed "s/USER_PLACEHOLDER/$_user/g" /usr/share/hyprcaffeine/polkit.rules \
        > /etc/polkit-1/rules.d/50-hyprcaffeine.rules 2>/dev/null || true
    
    # Waybar + systemd + keybinds (como usuario)
    su - "$_user" -c "bash /usr/share/hyprcaffeine/scripts/post-install.sh" 2>/dev/null
}
```

---

## Decisiones de Diseño

### ¿Por qué Bash y no un lenguaje compilado?
- Zero dependencias de build (solo bash, jq, hyprland, socat)
- Fácil de debuggear en Hyprland (los scripts se pueden leer/editar)
- Post-install puede hacerse desde pacman sin toolchains
- Contraparte: Bash tiene limitaciones (arrays, manejo de errores, fish compatibility)

### ¿Por qué Walker y no Rofi/wofi?
- Walker es GTK4 nativo con theming CSS completo
- Soporta modo "quick menu" con `--stdin`/`--stdout` pipe
- Estilo visual más moderno y personalizable
- El tema se carga como directorio (`themes/<name>/style.css`), no archivo suelto

### ¿Por qué release assets y no archive URLs?
- GitHub CDN sirve tarballs inconsistentes para el mismo commit desde diferentes nodos
- Los release assets son estáticos e inmutables
- Solución documentada en sección [AUR Packaging](#aur-packaging)

### ¿Por qué usar `find` para el directorio de source en PKGBUILD?
- Los archive URLs producen directorios con SHA corto (`pkg-6fb2702/`)
- Los release assets producen directorios según el contenido del tarball
- `find "$srcdir" -maxdepth 1 -type d -name 'pkg*'` funciona con cualquier formato

### ¿Por qué comentar (no borrar) los binds de Omarchy?
- El usuario puede querer restaurarlos fácilmente
- `keybinds remove` descomenta automáticamente
- No se pierde la configuración original del usuario

### ¿Por qué rutas absolutas en los keybinds?
- Hyprland no siempre tiene `~/.local/bin/` en su PATH
- La sesión de Hyprland puede ejecutar binds antes de que el shell del usuario cargue el PATH
- `command -v hyprcaffeine` resuelve la ruta completa en tiempo de instalación

---

## Pitfalls Conocidos

### 🚨 CRÍTICOS

| Pitfall | Síntoma | Solución |
|---|---|---|
| **CDN sha mismatch** | `sha256sums ... FAILED` | Usar release assets, calcular sha desde target |
| **Retag** | sha cambia cada vez, loop infinito | Bump version, nunca retag |
| **grep sin coma final** | Falsos positivos (`D` vs `Delete`) | Siempre `bind.*${combo},` |
| **Early return antes de resolución** | Conflictos no resueltos en reinstalación | Resolver conflictos ANTES del up-to-date check |
| **Fish shell over SSH** | Wildcards fallan, process substitution no funciona | Envolver en `bash -c '...'` |
| **SRCDEST/SRCINFO** | `No AUR package found` | Una dependencia por línea en .SRCINFO |
| **Pacman post-install quoting** | Post-install falla silenciosamente | NO usar heredocs en .install, delegar a script separado |

### ⚠️ IMPORTANTES

| Pitfall | Solución |
|---|---|
| `bindd` vs `bind` priority | Comentar el conflicto, no confiar en last-one-wins |
| Waybar position (dentro vs fuera de grupo) | Siempre sibling de `group/tray-expander`, no dentro |
| CSS detection (comentarios vs contenido real) | Buscar `#custom-hyprcaffeine`, no `/* HyprCaffeine */` |
| yay SKIPPGPCHECK warning | Quitar PGP de PKGBUILD (yay lo hardcodea) |
| makepkg pollutes git dir | Agregar `src/`, `pkg/`, `*.tar.gz` a .gitignore |
| Timer PID file stale | Mata proceso existente antes de crear nuevo PID |

---

## Diagrama de Flujo

```
                    ┌─────────────────────┐
                    │   hyprcaffeine       │
                    │   (CLI entry point)  │
                    └──────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    │   Parse subcommand   │
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
   ┌──────────┐         ┌──────────┐          ┌──────────┐
   │ Idle     │         │ Monitor  │          │ Lid      │
   │ on/off   │         │ on/off   │          │ on/off   │
   └────┬─────┘         └────┬─────┘          └────┬─────┘
        │                    │                     │
        ▼                    ▼                     ▼
   ┌──────────┐         ┌──────────┐          ┌──────────┐
   │ hyprctl  │         │ hyprctl  │          │ systemd- │
   │ inhibit  │         │ dpms on  │          │ inhibit  │
   └──────────┘         └──────────┘          └──────────┘
        │                    │                     │
        └────────────────────┼─────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   state.sh      │
                    │ update state.json│
                    └─────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   notify.sh     │
                    │   notify-send   │
                    └─────────────────┘


                    ┌─────────────────────┐
                    │ hyprcaffeine keybinds│
                    │      install        │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │ Resolve Omarchy conflicts│
                    │ (comenta binds duplicados)│
                    └─────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │  Check up-to-date?      │
                    │  ┌─── yes ───→ return   │
                    │  └─── no ───── continue  │
                    └─────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │ Generate keybinds file   │
                    │ ~/.config/hypr/          │
                    │ hyprcaffeine-keybinds.*  │
                    └─────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │ Add source to           │
                    │ hyprland.conf (END)     │
                    └─────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │  hyprctl reload         │
                    └─────────────────────────┘


                    ┌─────────────────────┐
                    │   Release Flow      │
                    └──────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    │  git tag vX.Y.Z     │
                    │  git push tags      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │  gh release create      │
                    │  vX.Y.Z --notes-file    │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │  Download tarball       │
                    │  from TARGET machine    │
                    │  → sha256sum            │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │  Upload as release asset│
                    │  gh release upload      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │  Update PKGBUILD:       │
                    │  • source = release URL │
                    │  • sha256 = target's    │
                    │  • NO retag             │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │  AUR: clone → copy      │
                    │  → regen .SRCINFO       │
                    │  → commit → push        │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────────┐
                    │  TEST on target:        │
                    │  yay -S hyprcaffeine    │
                    └─────────────────────────┘
```

---

> **Última actualización:** v0.7.4-2 (Mayo 2026)
> **Mantenido por:** Hans-Dieter Buddenberg
> **Licencia:** MIT
