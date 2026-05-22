#!/usr/bin/env bash
# build-local.sh — Build HyprCaffeine package locally for testing before AUR upload
#
# Usage:
#   ./build-local.sh              # Build only  → tells you to: sudo pacman -U <pkg>
#   ./build-local.sh --install    # Build + install via makepkg -si
#   ./build-local.sh --bump       # Increment pkgrel before building
#   ./build-local.sh --bump --install

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_SRC="${SCRIPT_DIR}/PKGBUILD"

# ── Parse args ───────────────────────────────────────────────────────────────
DO_INSTALL=false
DO_BUMP=false
for arg in "$@"; do
    case "${arg}" in
        --install|-i) DO_INSTALL=true ;;
        --bump|-b)    DO_BUMP=true ;;
        --help|-h)
            echo "Usage: ./build-local.sh [--install] [--bump]"
            echo "  --install   Build and install with makepkg -si"
            echo "  --bump      Increment pkgrel in PKGBUILD before building"
            exit 0 ;;
        *) echo "Unknown option: ${arg}"; exit 1 ;;
    esac
done

# ── Read version from PKGBUILD ────────────────────────────────────────────────
PKGNAME=$(grep '^pkgname=' "${PKGBUILD_SRC}" | cut -d= -f2)
VERSION=$(grep '^pkgver=' "${PKGBUILD_SRC}" | cut -d= -f2)
PKGREL=$(grep '^pkgrel=' "${PKGBUILD_SRC}" | cut -d= -f2)

if [[ "${DO_BUMP}" == true ]]; then
    PKGREL=$(( PKGREL + 1 ))
    sed -i "s/^pkgrel=.*/pkgrel=${PKGREL}/" "${PKGBUILD_SRC}"
    echo "  pkgrel bumped → ${PKGREL}"
fi

TARBALL="${PKGNAME}-${VERSION}.tar.gz"

echo ""
echo "  󰒲 HyprCaffeine — Local Build v${VERSION}-${PKGREL}"
echo "  ──────────────────────────────────────────"
echo ""

# ── Create temp build dir ─────────────────────────────────────────────────────
BUILD_DIR="$(mktemp -d /tmp/hc-build-XXXXXX)"
echo "  Build dir: ${BUILD_DIR}"
echo ""

# Show build dir on exit for inspection
trap 'echo ""; echo "  Build dir preserved: ${BUILD_DIR}"' EXIT

# ── 1. Create source tarball from working tree ────────────────────────────────
echo "  [1/4] Creating source tarball (current working tree)..."
tar czf "${BUILD_DIR}/${TARBALL}" \
    --directory="${SCRIPT_DIR}" \
    --transform "s|^\\./|${PKGNAME}-${VERSION}/|" \
    --exclude='./.git' \
    --exclude='./*.pkg.tar.*' \
    --exclude='./src' \
    --exclude='./pkg' \
    --exclude='./*.tar.gz' \
    .
echo "        ✅ ${TARBALL}"

# ── 2. Compute sha256 ─────────────────────────────────────────────────────────
echo "  [2/4] Computing sha256sum..."
CHECKSUM=$(sha256sum "${BUILD_DIR}/${TARBALL}" | awk '{print $1}')
echo "        ${CHECKSUM}"

# ── 3. Patch PKGBUILD for local source ───────────────────────────────────────
echo "  [3/4] Patching PKGBUILD..."
cp "${PKGBUILD_SRC}" "${BUILD_DIR}/PKGBUILD"
cp "${SCRIPT_DIR}/hyprcaffeine.install" "${BUILD_DIR}/hyprcaffeine.install"

# Replace remote URL source with local tarball filename (makepkg finds it in CWD)
sed -i \
    -e "s|^pkgrel=.*|pkgrel=${PKGREL}|" \
    -e "s|^source=(.*)|source=(\"${TARBALL}\")|" \
    -e "s|^sha256sums=(.*)|sha256sums=(\"${CHECKSUM}\")|" \
    "${BUILD_DIR}/PKGBUILD"
echo "        ✅ Source and checksums patched"

# ── 4. Build ──────────────────────────────────────────────────────────────────
echo "  [4/4] Running makepkg..."
echo ""
cd "${BUILD_DIR}"

if [[ "${DO_INSTALL}" == true ]]; then
    makepkg -si
    echo ""
    echo "  ✅ Installed! Verify with: hyprcaffeine status"
    echo "  Post-install: hyprcaffeine setup   (if polkit/waybar wasn't auto-configured)"
else
    makepkg -s
    PKG_FILE=$(ls "${BUILD_DIR}"/*.pkg.tar.* 2>/dev/null | head -1)
    echo ""
    echo "  ✅ Package built:"
    echo "     ${PKG_FILE}"
    echo ""
    echo "  Install with:"
    echo "     sudo pacman -U ${PKG_FILE}"
    echo ""
    echo "  Or build + install in one step:"
    echo "     ./build-local.sh --install"
fi
