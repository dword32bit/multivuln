#!/bin/bash
# Vuln Lab ULTIMATE Installer - Extended Edition
# Includes multiple vulnerable web apps with local caching to /opt/multivuln

set -e

MULTIVULN_DIR="/opt/multivuln"
WWW_DIR="/var/www/html"
MYSQL_ROOT_PW="rootpass"

mkdir -p "$MULTIVULN_DIR"

log_info() {
  echo -e "\033[1;34m[+] $1\033[0m"
}

log_warn() {
  echo -e "\033[1;33m[!] $1\033[0m"
}

download_or_use_cache() {
  local url="$1"
  local dest="$2"
  local filename=$(basename "$dest")

  if [ -f "$MULTIVULN_DIR/$filename" ]; then
    log_info "Using cached $filename from $MULTIVULN_DIR"
    cp "$MULTIVULN_DIR/$filename" "$dest"
  else
    log_info "Downloading $filename..."
    wget "$url" -O "$dest"
    cp "$dest" "$MULTIVULN_DIR/$filename"
  fi
}

install_sqlilabs() {
  log_info "Installing SQLi-Labs..."
  rm -rf "$WWW_DIR/sqlilabs"
  git clone https://github.com/Audi-1/sqli-labs.git "$WWW_DIR/sqlilabs"
  chown -R www-data:www-data "$WWW_DIR/sqlilabs"
}

install_mutillidae() {
  log_info "Installing Mutillidae II..."
  rm -rf "$WWW_DIR/mutillidae"
  git clone https://github.com/webpwnized/mutillidae.git "$WWW_DIR/mutillidae"
  chown -R www-data:www-data "$WWW_DIR/mutillidae"
}

install_webgoat() {
  log_info "Installing WebGoat..."
  local jar="$MULTIVULN_DIR/webgoat.jar"
  download_or_use_cache "https://github.com/WebGoat/WebGoat/releases/latest/download/webgoat-server.jar" "$jar"
  cp "$jar" "$WWW_DIR/webgoat.jar"
  chmod +x "$WWW_DIR/webgoat.jar"
  log_info "WebGoat jar copied to $WWW_DIR/webgoat.jar. Run manually with: java -jar /var/www/html/webgoat.jar"
}

install_xvwa() {
  log_info "Installing XVWA..."
  rm -rf "$WWW_DIR/xvwa"
  git clone https://github.com/s4n7h0/xvwa.git "$WWW_DIR/xvwa"
  chown -R www-data:www-data "$WWW_DIR/xvwa"
}

install_security_shepherd() {
  log_info "Installing OWASP Security Shepherd..."
  rm -rf "$WWW_DIR/shepherd"
  git clone https://github.com/OWASP/SecurityShepherd.git "$WWW_DIR/shepherd"
  chown -R www-data:www-data "$WWW_DIR/shepherd"
}

configure_apache() {
  log_info "Configuring Apache Web Server..."
  a2enmod rewrite
  systemctl restart apache2
  log_info "Apache restarted. Apps are hosted in $WWW_DIR"
}

# Installation steps
apt update
apt install -y apache2 php php-mysqli mariadb-server git unzip curl openjdk-17-jre-headless wget

systemctl enable apache2
systemctl start apache2
systemctl start mysql || service mysql start

install_sqlilabs
install_mutillidae
install_webgoat
install_xvwa
install_security_shepherd

configure_apache

log_info "All selected apps have been installed."
