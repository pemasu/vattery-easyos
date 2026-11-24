#!/bin/sh
# Build and install vattery on EasyOS (only gcc and GTK2 needed, no Vala or autotools).
# vattery (c) 2011 Jezra J Lickter, GPL v3+; see AUTHORS and README-EASYOS.
#   ./build-easyos.sh            compile ./vattery
#   ./build-easyos.sh install    copy it into the system + start with the desktop
#   ./build-easyos.sh uninstall  remove it again
set -e
cd "$(dirname "$0")"
VERSION="0.7.6-easyos"
PREFIX="${PREFIX:-/usr/local}"

build() {
  if ! command -v gcc >/dev/null 2>&1 || ! command -v pkg-config >/dev/null 2>&1; then
    echo "gcc/pkg-config not found."
    echo "On EasyOS 7: click the 'devx' container icon on the desktop and run this script there,"
    echo "or load the devx SFS on the main desktop."
    exit 1
  fi
  if ! pkg-config --exists gtk+-2.0; then
    echo "GTK2 development files not found. Install them with:"
    echo "  apt install libgtk2.0-dev     (or search 'libgtk2.0-dev' in PKGget)"
    exit 1
  fi
  cat > src/config.h <<EOH
#define GETTEXT_PACKAGE "vattery"
#define PACKAGE_NAME "vattery"
#define PACKAGE_STRING "vattery $VERSION"
#define PACKAGE_VERSION "$VERSION"
EOH
  echo "Compiling vattery $VERSION..."
  gcc -O2 -w -Isrc -include src/config.h \
    -DLOCALEDIR="\"/usr/share/locale\"" -DPKGDATADIR="\"/usr/share/vattery\"" \
    -DPKGLIBDIR="\"/usr/lib/vattery\"" \
    -o vattery src/main.c src/configuration.c src/configurationGUI.c src/battery.c src/conservation.c \
    $(pkg-config --cflags --libs gtk+-2.0)
  echo "Built ./vattery"
}

install_it() {
  [ -x ./vattery ] || build
  install -Dm755 vattery "$PREFIX/bin/vattery"
  install -Dm755 easyos/vattery-alert "$PREFIX/bin/vattery-alert"
  install -Dm644 easyos/vattery.desktop /usr/share/applications/vattery.desktop
  if [ -d /root/Startup ]; then
    install -Dm755 easyos/Startup-vattery /root/Startup/vattery
    echo "vattery will start automatically with the desktop (/root/Startup/vattery)."
  fi
  if ! ls /usr/lib/*/gdk-pixbuf-2.0/*/loaders/*svg* >/dev/null 2>&1 \
     && ! ls /usr/lib/gdk-pixbuf-2.0/*/loaders/*svg* >/dev/null 2>&1; then
    echo "NOTE: SVG image support looks missing; the tray icon needs it."
    echo "      Install it with: apt install librsvg2-common"
  fi
  echo "Installed. Run 'vattery &' to start it now."
}

uninstall_it() {
  rm -f "$PREFIX/bin/vattery" "$PREFIX/bin/vattery-alert" \
    /usr/share/applications/vattery.desktop /root/Startup/vattery
  echo "Removed vattery (your settings in ~/.config/vattery were kept)."
}

case "$1" in
  install) install_it ;;
  uninstall) uninstall_it ;;
  ""|build) build ;;
  *) echo "usage: $0 [build|install|uninstall]"; exit 1 ;;
esac
