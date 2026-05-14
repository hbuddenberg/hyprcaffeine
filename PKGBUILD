# Maintainer: HyprCaffeine Contributors
pkgname=hyprcaffeine
pkgver=0.1.0
pkgrel=1
pkgdesc='Modern idle inhibition utility for Hyprland'
arch=(any)
url='https://github.com/hyprcaffeine/hyprcaffeine'
license=(MIT)
depends=(bash jq hyprland gum)
optdepends=(
    'walker: application launcher for the menu'
    'wofi: alternative launcher for the menu'
)
source=()
sha256sums=()

package() {
    # Binary
    install -Dm755 "${srcdir}/../bin/hyprcaffeine" \
        "${pkgdir}/usr/bin/hyprcaffeine"

    # Scripts / data
    if [[ -d "${srcdir}/../scripts" ]]; then
        install -dm755 "${pkgdir}/usr/share/hyprcaffeine"
        cp -r "${srcdir}/../scripts/"* "${pkgdir}/usr/share/hyprcaffeine/"
    fi

    # Default configuration
    install -Dm644 "${srcdir}/../config/default.yaml" \
        "${pkgdir}/usr/share/hyprcaffeine/default.yaml"

    # Waybar module
    install -Dm644 "${srcdir}/../waybar/module.json" \
        "${pkgdir}/usr/share/hyprcaffeine/waybar-module.json"

    # Documentation
    install -dm755 "${pkgdir}/usr/share/doc/hyprcaffeine"
    install -Dm644 "${srcdir}/../README.md" \
        "${pkgdir}/usr/share/doc/hyprcaffeine/README.md"
    install -Dm644 "${srcdir}/../docs/INSTALL.md" \
        "${pkgdir}/usr/share/doc/hyprcaffeine/INSTALL.md"
    install -Dm644 "${srcdir}/../docs/CONFIG.md" \
        "${pkgdir}/usr/share/doc/hyprcaffeine/CONFIG.md"
    install -Dm644 "${srcdir}/../docs/WAYBAR.md" \
        "${pkgdir}/usr/share/doc/hyprcaffeine/WAYBAR.md"

    # License
    install -Dm644 "${srcdir}/../LICENSE" \
        "${pkgdir}/usr/share/licenses/hyprcaffeine/LICENSE"
}
