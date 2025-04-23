#!/bin/bash

set -e

CACHE_DIR="/opt/multivuln"
INSTALL_DIR="/var/www/html"
mkdir -p "$CACHE_DIR"
mkdir -p "$INSTALL_DIR"

function download_and_extract {
    NAME=$1
    URL=$2
    FILE=$3
    DEST_DIR=$4

    echo "[*] Installing $NAME..."

    if [ -f "$CACHE_DIR/$FILE" ]; then
        echo "[+] Using cached $FILE"
    else
        echo "[!] Downloading $FILE..."
        wget -O "$CACHE_DIR/$FILE" "$URL"
    fi

    echo "[+] Extracting $FILE to $DEST_DIR..."
    mkdir -p "$DEST_DIR"
    case $FILE in
        *.zip)
            unzip -qo "$CACHE_DIR/$FILE" -d "$DEST_DIR" || echo "[!] Warning: unzip failed for $FILE"
            ;;
        *.tgz | *.tar.gz)
            tar -xzf "$CACHE_DIR/$FILE" -C "$DEST_DIR"
            ;;
        *)
            echo "[!] Unsupported file type for $FILE"
            ;;
    esac
    echo "[+] $NAME installed."
    echo
}

# List of apps to install
apps=(
    "Mutillidae|https://github.com/webpwnized/mutillidae/archive/refs/heads/master.zip|mutillidae.zip"
    "NodeGoat|https://github.com/OWASP/NodeGoat/archive/refs/heads/master.zip|nodegoat.zip"
    "SecurityShepherd|https://github.com/OWASP/SecurityShepherd/archive/refs/heads/master.zip|securityshepherd.zip"
    "Hackazon|https://github.com/rapid7/hackazon/archive/refs/heads/master.zip|hackazon.zip"
    "XSSGame|https://github.com/google/xss-game/archive/refs/heads/master.zip|xss-game.zip"
    "PixiCR|https://github.com/sectooladdict/pixi-cr/archive/refs/heads/master.zip|pixi-cr.zip"
)

for app in "${apps[@]}"; do
    IFS='|' read -r NAME URL FILE <<< "$app"
    download_and_extract "$NAME" "$URL" "$FILE" "$INSTALL_DIR/$NAME"
done

echo "[✓] All apps installed!"
