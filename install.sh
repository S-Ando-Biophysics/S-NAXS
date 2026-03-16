#!/usr/bin/env bash

set -e

echo "Installing S-NAXS..."

INSTALL_DIR="/usr/local/bin"

if [ ! -w "$INSTALL_DIR" ]; then
    sudo cp bin/S-NAXS.sh "$INSTALL_DIR/S-NAXS"
    sudo chmod +x "$INSTALL_DIR/S-NAXS"
else
    cp bin/S-NAXS.sh "$INSTALL_DIR/S-NAXS"
    chmod +x "$INSTALL_DIR/S-NAXS"
fi

VERSION=$(cat VERSION)

echo ""
echo "S-NAXS version ${VERSION} installed."
