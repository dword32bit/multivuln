#!/bin/bash

# Direktori cache untuk semua file download
CACHE_DIR="/opt/multivuln"
WEBROOT="/var/www/html"

# Pastikan direktori cache dan webroot ada
mkdir -p "$CACHE_DIR"
mkdir -p "$WEBROOT"

# Fungsi untuk mendownload dan menyimpan ke cache
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

# Fungsi untuk mengekstrak zip ke webroot
extract_to_webroot() {
    local file="$1"
    local folder="$2"

    unzip -qo "$file" -d "$WEBROOT/$folder"
    echo "[+] $folder installed."
}

# Fungsi untuk clone git repo ke webroot
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

# Fungsi untuk konfigurasi Apache
setup_apache() {
    echo "[*] Setting up Apache web server..."
    apt-get update -qq && apt-get install -y apache2 php unzip git mariadb-server libapache2-mod-php php-mysqli > /dev/null
    systemctl enable apache2 && systemctl start apache2
    chown -R www-data:www-data "$WEBROOT"
    echo "[+] Apache configured."
}

# Mulai setup
setup_apache

# Daftar aplikasi
# Format: nama_folder|download_url|filename|tipe
apps=(
    "DVWA|https://github.com/digininja/DVWA/archive/refs/heads/master.zip|dvwa.zip|zip"
    "bWAPP|https://sourceforge.net/projects/bwapp/files/latest/download|bwapp.zip|zip"
    "Hackazon|https://github.com/rapid7/hackazon/archive/master.zip|hackazon.zip|zip"
    "XVWA|https://github.com/s4n7h0/xvwa/archive/master.zip|xvwa.zip|zip"
    "SecurityShepherd|https://github.com/OWASP/SecurityShepherd/archive/master.zip|shepherd.zip|zip"
)

# Proses instalasi
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
    sleep 1
    
    # Konfigurasi khusus untuk database (jika diperlukan)
    if [[ "$name" == "XVWA" ]]; then
        echo "[*] Setting up database for XVWA..."
        mysql -u root -e "CREATE DATABASE IF NOT EXISTS xvwa;"
    elif [[ "$name" == "SecurityShepherd" ]]; then
        echo "[*] Setting up database for Security Shepherd..."
        mysql -u root -e "CREATE DATABASE IF NOT EXISTS securityshepherd;"
    fi

done

echo "[+] All apps installed and Apache is running at http://localhost"
