#!/bin/bash

# Direktori cache dan webroot
CACHE_DIR="/opt/multivuln"
WEBROOT="/var/www/html"

# Pastikan direktori ada
mkdir -p "$CACHE_DIR"
mkdir -p "$WEBROOT"

# Hapus semua isi webroot (bersih total)
echo "[*] Cleaning up $WEBROOT..."
rm -rf "$WEBROOT"/*

# Fungsi untuk download dengan cache
cached_download() {
    local url="$1"
    local filename="$2"
    local dest="$CACHE_DIR/$filename"

    echo "[*] Checking cache for $filename..."
    if [ -f "$dest" ]; then
        echo "[+] Found in cache: $filename"
    else
        echo "[*] Downloading $filename..."
        wget -q --show-progress "$url" -O "$dest"
    fi
}

# Fungsi ekstrak ZIP
extract_to_webroot() {
    local file="$1"
    local folder="$2"
    local dest="$WEBROOT/$folder"

    mkdir -p "$dest"
    unzip -qo "$file" -d "$dest"
    echo "[+] $folder installed."
}

# Git clone ke webroot
git_clone_to_webroot() {
    local repo="$1"
    local folder="$2"

    if [ ! -d "$WEBROOT/$folder" ]; then
        git clone "$repo" "$WEBROOT/$folder"
        echo "[+] $folder cloned."
    else
        echo "[+] $folder already cloned."
    fi
}

# Setup Apache
setup_apache() {
    echo "[*] Setting up Apache web server..."
    apt-get update -qq && apt-get install -y apache2 php unzip git mariadb-server libapache2-mod-php php-mysqli > /dev/null
    systemctl enable apache2 && systemctl start apache2
    chown -R www-data:www-data "$WEBROOT"
    echo "[+] Apache configured."
}

# Buat halaman index.php
generate_index() {
    echo "[*] Generating index.php..."
    {
        echo "<?php"
        echo "echo '<html><head><title>Vuln Lab</title></head><body><h1>Vulnerable Web Apps</h1><ul>';"
        echo "foreach (scandir('.') as \$entry) {"
        echo "  if (\$entry !== '.' && \$entry !== '..' && is_dir(\$entry)) {"
        echo "    echo \"<li><a href='/\$entry'>\$entry</a></li>\";"
        echo "  }"
        echo "}"
        echo "echo '</ul></body></html>';"
        echo "?>"
    } > "$WEBROOT/index.php"
    echo "[+] index.php created."
}

# Setup MySQL passwordless root (only if no password set)
secure_mysql() {
    echo "[*] Configuring MySQL root access..."
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; FLUSH PRIVILEGES;" 2>/dev/null
}

# Setup
setup_apache
secure_mysql

# Aplikasi yang akan diinstall
apps=(
    "DVWA|https://github.com/digininja/DVWA/archive/refs/heads/master.zip|dvwa.zip|zip"
    "bWAPP|https://downloads.sourceforge.net/project/bwapp/bwapp.zip|bwapp.zip|zip"
    "Hackazon|https://github.com/rapid7/hackazon/archive/master.zip|hackazon.zip|zip"
    "XVWA|https://github.com/s4n7h0/xvwa/archive/master.zip|xvwa.zip|zip"
    "SecurityShepherd|https://github.com/OWASP/SecurityShepherd/archive/master.zip|shepherd.zip|zip"
)

for entry in "${apps[@]}"; do
    IFS='|' read -r name url filename type <<< "$entry"

    echo "[*] Installing $name..."
    cached_download "$url" "$filename"
    case $type in
        zip)
            extract_to_webroot "$CACHE_DIR/$filename" "$name"
            ;;
        *)
            echo "[!] Unknown type $type for $name"
            ;;
    esac
    echo

    # Database setup
    if [[ "$name" == "XVWA" ]]; then
        echo "[*] Setting up database for XVWA..."
        mysql -u root -e "CREATE DATABASE IF NOT EXISTS xvwa;" 2>/dev/null
    elif [[ "$name" == "SecurityShepherd" ]]; then
        echo "[*] Setting up database for Security Shepherd..."
        mysql -u root -e "CREATE DATABASE IF NOT EXISTS securityshepherd;" 2>/dev/null
    fi

done

generate_index

echo "[+] All apps installed and Apache is running at http://localhost"
