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

# Fungsi ekstrak ZIP ke folder cache (tidak ke webroot langsung)
extract_zip() {
    local file="$1"
    local tempdir="$CACHE_DIR/extracted_$(basename "$file" .zip)"

    if [ ! -d "$tempdir" ]; then
        mkdir -p "$tempdir"
        unzip -q "$file" -d "$tempdir"
    fi
    echo "$tempdir"
}

# Setup Apache
setup_apache() {
    echo "[*] Setting up Apache web server..."
    apt-get update -qq && apt-get install -y apache2 php unzip git mariadb-server libapache2-mod-php php-mysqli > /dev/null
    systemctl enable apache2 && systemctl restart apache2
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

# Setup MySQL passwordless root
secure_mysql() {
    echo "[*] Configuring MySQL root access..."
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; FLUSH PRIVILEGES;" 2>/dev/null
}

# Fungsi generik untuk install aplikasi dari folder
install_app() {
    local zipname="$1"
    local webdir="$2"
    local dbname="$3"
    local subdir="$4"

    local tempdir=$(extract_zip "$CACHE_DIR/$zipname")
    local sourcedir="$tempdir"

    if [ -n "$subdir" ]; then
        sourcedir="$tempdir/$subdir"
    fi

    mkdir -p "$WEBROOT/$webdir"
    cp -r "$sourcedir"/* "$WEBROOT/$webdir/"
    [ -n "$dbname" ] && mysql -u root -e "CREATE DATABASE IF NOT EXISTS $dbname;"
    echo "[+] $webdir installed."
}

# Setup
setup_apache
secure_mysql

# Download file yang dibutuhkan
cached_download "https://github.com/digininja/DVWA/archive/refs/heads/master.zip" "dvwa.zip"
cached_download "https://downloads.sourceforge.net/project/bwapp/bwapp.zip" "bwapp.zip"
cached_download "https://github.com/rapid7/hackazon/archive/master.zip" "hackazon.zip"
cached_download "https://github.com/s4n7h0/xvwa/archive/master.zip" "xvwa.zip"
cached_download "https://github.com/OWASP/SecurityShepherd/archive/master.zip" "shepherd.zip"

# Install aplikasi
install_app "dvwa.zip" "DVWA" "dvwa" "DVWA-master"
install_app "bwapp.zip" "bWAPP" "bWAPP" ""
install_app "hackazon.zip" "Hackazon" "" "hackazon-master"
install_app "xvwa.zip" "XVWA" "xvwa" "xvwa-master"
install_app "shepherd.zip" "SecurityShepherd" "securityshepherd" "SecurityShepherd-master"

generate_index

echo "[+] All apps installed and Apache is running at http://localhost"
