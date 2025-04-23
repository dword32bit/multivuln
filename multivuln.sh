#!/bin/bash

set -e

CACHE_DIR="/opt/multivuln"
mkdir -p "$CACHE_DIR"

download_if_not_exist() {
    local url="$1"
    local filename="$2"
    if [ ! -f "$CACHE_DIR/$filename" ]; then
        echo "Downloading $filename..."
        curl -L "$url" -o "$CACHE_DIR/$filename"
    else
        echo "Using cached $filename"
    fi
}

install_dvwa() {
    echo "[*] Installing DVWA..."
    download_if_not_exist "https://github.com/digininja/DVWA/archive/refs/heads/master.zip" "dvwa.zip"
    unzip -o "$CACHE_DIR/dvwa.zip" -d /var/www/html/
    mv /var/www/html/DVWA-master /var/www/html/dvwa
    echo "[+] DVWA installed."
}

install_bwapp() {
    echo "[*] Installing bWAPP..."
    download_if_not_exist "http://www.itsecgames.com/download/bWAPP.zip" "bwapp.zip"
    unzip -o "$CACHE_DIR/bwapp.zip" -d /var/www/html/
    echo "[+] bWAPP installed."
}

install_webgoat() {
    echo "[*] Installing WebGoat..."
    download_if_not_exist "https://github.com/WebGoat/WebGoat/releases/download/v8.2.0/WebGoat-8.2.0.jar" "WebGoat.jar"
    cp "$CACHE_DIR/WebGoat.jar" /opt/
    echo "[+] WebGoat installed. Run it with: java -jar /opt/WebGoat.jar"
}

install_mutillidae() {
    echo "[*] Installing OWASP Mutillidae II..."
    download_if_not_exist "https://github.com/webpwnized/mutillidae/archive/refs/heads/master.zip" "mutillidae.zip"
    unzip -o "$CACHE_DIR/mutillidae.zip" -d /var/www/html/
    mv /var/www/html/mutillidae-master /var/www/html/mutillidae
    echo "[+] Mutillidae installed."
}

install_hackazon() {
    echo "[*] Installing Hackazon..."
    download_if_not_exist "https://github.com/rapid7/hackazon/archive/refs/heads/master.zip" "hackazon.zip"
    unzip -o "$CACHE_DIR/hackazon.zip" -d /var/www/html/
    mv /var/www/html/hackazon-master /var/www/html/hackazon
    echo "[+] Hackazon installed."
}

install_dvwa
install_bwapp
install_webgoat
install_mutillidae
install_hackazon

echo "[✓] All installations completed."
