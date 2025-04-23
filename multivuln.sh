
#!/bin/bash
# Vuln Lab ULTIMATE Installer - by dword32bit

set -e

MYSQL_ROOT_PW="rootpass"

log_info() {
  echo -e "\033[1;34m[+] $1\033[0m"
}

log_warn() {
  echo -e "\033[1;33m[!] $1\033[0m"
}

reset_mysql_password() {
  log_info "Fixing MySQL root access..."
  sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PW}';
FLUSH PRIVILEGES;
EOF
}

check_and_install_node() {
  NODE_VERSION=$(node -v 2>/dev/null || echo "v0.0.0")
  if [[ "$NODE_VERSION" < "v14" ]]; then
    log_info "Installing Node.js 18.x (LTS)..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
  fi
}

install_wordpress() {
  VERSION=$1
  DEST="/var/www/html/wordpress-${VERSION}"
  DBNAME="wp${VERSION//./}"
  log_info "Installing WordPress $VERSION..."
  rm -rf "$DEST"
  mkdir -p "$DEST"
  wget https://wordpress.org/wordpress-${VERSION}.tar.gz -O /tmp/wp${VERSION}.tar.gz
  tar -xzf /tmp/wp${VERSION}.tar.gz -C /tmp/
  mv /tmp/wordpress/* "$DEST"
  mysql -uroot -p${MYSQL_ROOT_PW} -e "DROP DATABASE IF EXISTS ${DBNAME}; CREATE DATABASE ${DBNAME};"
  cat <<EOF > "$DEST/wp-config.php"
<?php
define('DB_NAME', '${DBNAME}');
define('DB_USER', 'dvwa');
define('DB_PASSWORD', 'p@ssw0rd');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
\$table_prefix = 'wp_';
define('WP_DEBUG', false);
if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
EOF
  chown -R www-data:www-data "$DEST"
}

log_info "Installing dependencies..."
apt update && apt install -y apache2 php php-mysqli mariadb-server git unzip curl vsftpd openssh-server     nodejs npm netcat gcc g++ build-essential libcap2-bin wget php-curl php-gd php-xml php-mbstring php-zip

log_info "Starting MySQL..."
systemctl start mysql || service mysql start

log_info "Configuring MySQL root access..."
if ! mysql -uroot -p"${MYSQL_ROOT_PW}" -e "SELECT 1;" >/dev/null 2>&1; then
  reset_mysql_password
fi

log_info "Creating DVWA database and user..."
mysql -uroot -p${MYSQL_ROOT_PW} -e "DROP DATABASE IF EXISTS dvwa; CREATE DATABASE dvwa;"
mysql -uroot -p${MYSQL_ROOT_PW} -e "CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';"
mysql -uroot -p${MYSQL_ROOT_PW} -e "GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';"

log_info "Installing/Resetting DVWA..."
rm -rf /var/www/html/dvwa
git clone https://github.com/digininja/DVWA.git /var/www/html/dvwa
cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php
sed -i "s/'root'/'dvwa'/; s/''/'p@ssw0rd'/" /var/www/html/dvwa/config/config.inc.php

log_info "Installing/Resetting bWAPP..."
rm -rf /var/www/html/bwapp
mkdir -p /var/www/html/bwapp
wget https://sourceforge.net/projects/bwapp/files/latest/download -O /tmp/bwapp.zip
unzip -o /tmp/bwapp.zip -d /var/www/html/bwapp
mv /var/www/html/bwapp/bWAPP/* /var/www/html/bwapp/
mysql -uroot -p${MYSQL_ROOT_PW} -e "DROP DATABASE IF EXISTS bwapp; CREATE DATABASE bwapp;"
mysql -uroot -p${MYSQL_ROOT_PW} -e "GRANT ALL ON bwapp.* TO 'dvwa'@'localhost';"

log_info "Installing/Resetting Mutillidae..."
rm -rf /var/www/html/mutillidae
git clone https://github.com/webpwnized/mutillidae.git /var/www/html/mutillidae

check_and_install_node

log_info "Installing/Resetting Juice Shop..."
rm -rf /opt/juice-shop
mkdir -p /opt/juice-shop
cd /opt/juice-shop
git clone https://github.com/bkimminich/juice-shop.git .
npm install --legacy-peer-deps || true
nohup npm start &

install_wordpress "4.7"
install_wordpress "4.8"

log_info "Installing Simple Blog..."
rm -rf /var/www/html/simple-blog
git clone https://github.com/l33t-haxor/simple-php-blog-vuln.git /var/www/html/simple-blog

log_info "Creating index page for vulnerable apps..."
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
  <title>Vuln Lab Entry</title>
  <style>
    body { font-family: monospace; padding: 30px; background: #111; color: #0f0; }
    a { color: #00f; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <h2>Vuln Lab Targets</h2>
  <ol>
    <li><a href="/mutillidae" target="_blank">Mutillidae</a></li>
    <li><a href="/dvwa" target="_blank">DVWA</a></li>
    <li><a href="/bwapp" target="_blank">bWAPP</a></li>
    <li><a href="http://localhost:3000" target="_blank">Juice Shop</a></li>
    <li><a href="/wordpress-4.7" target="_blank">WordPress 4.7</a></li>
    <li><a href="/wordpress-4.8" target="_blank">WordPress 4.8</a></li>
    <li><a href="/simple-blog" target="_blank">Simple Blog</a></li>
  </ol>
  <hr>
  <p>Reverse shell listener: <code>nc -lvnp 4444</code></p>
</body>
</html>
EOF

log_info "Script complete. Web UI and all vuln services are ready!"
