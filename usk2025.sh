#!/bin/bash

echo "===================================================="
echo " INSTALL DNS, LAMP, SAMBA, MAIL, dan Cacti SERVER DEBAIN 12"
echo "===================================================="

# Input domain
sleep 3
echo "----------------------------------------------------"
echo " DOMAIN 1 dan DOMAIN 2"
echo "----------------------------------------------------"
read -p "Masukkan Domain 1 - tkj[NIS] (contoh: tkj13930.my.id): " DOMAIN1
read -p "Masukkan Domain 2 - usk[NIS] (contoh: usk13930.net): " DOMAIN2

# Input ip address dan subnet mask
sleep 2
echo "----------------------------------------------------"
echo " IP ADDRESS dan SUBNET MASK"
echo "----------------------------------------------------"
read -p "Masukkan IP Address (contoh: 172.16.33.133): " IPADDR
read -p "Masukkan Subnet Mask (contoh: 255.255.255.128): " SUBNET

# Hitung Network Address
IFS='.' read -r i1 i2 i3 i4 <<< "$IPADDR"
IFS='.' read -r s1 s2 s3 s4 <<< "$SUBNET"
n1=$((i1 & s1))
n2=$((i2 & s2))
n3=$((i3 & s3))
n4=$((i4 & s4))
NETWORK="$n1.$n2.$n3.$n4/$(( (s1 * 16777216 + s2 * 65536 + s3 * 256 + s4) == 4294967040 ? 24 : (s1 * 16777216 + s2 * 65536 + s3 * 256 + s4) == 4294967168 ? 25 : 0 ))"
REVERSED_IP="$i3.$i2.$i1"

# Update package lists
sleep 2
echo "----------------------------------------------------"
echo "Update package lists"
echo "----------------------------------------------------"
apt update

# Install BIND9 and DNS utilities
sleep 2
echo "----------------------------------------------------"
echo "Install BIND9 dan DNS utilities"
echo "----------------------------------------------------"
apt install bind9 dnsutils -y

DO1=$(echo "$DOMAIN1" | cut -d '.' -f 1)
DO2=$(echo "$DOMAIN2" | cut -d '.' -f 1)

# Konfigurasi db.IP
cat > /etc/bind/db.$i1 <<EOF
\$TTL    604800
;
; BIND reverse data file for local loopback interface
;
@       IN      SOA     $DOMAIN1. root.$DOMAIN1. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $DOMAIN1.
$i4       IN      PTR     $DOMAIN1.
$i4       IN      PTR     $DOMAIN2.
$i4       IN      PTR     www.$DOMAIN1.
$i4       IN      PTR     www.$DOMAIN2.
$i4       IN      PTR     mail.$DOMAIN1.
$i4       IN      PTR     cacti.$DOMAIN2.
$i4       IN      PTR     voip.$DOMAIN2.
$i4       IN      PTR     cctv.$DOMAIN2.
EOF

# Konfigurasi db.domain 1
cat > /etc/bind/db.$DO1 <<EOF
\$TTL    604800
;
; BIND data file for local loopback interface
;
@       IN      SOA     $DOMAIN1. root.$DOMAIN1. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $DOMAIN1.
@       IN      A       $IPADDR
www     IN      A       $IPADDR
mail    IN      A       $IPADDR
$DOMAIN1. IN      MX      10      mail.$DOMAIN1.
EOF

# Konfigurasi db.domain 2
cat > /etc/bind/db.$DO2 <<EOF
\$TTL    604800
;
; BIND data file for local loopback interface
;
@       IN      SOA     $DOMAIN2. root.$DOMAIN2. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $DOMAIN2.
@       IN      A       $IPADDR
www     IN      A       $IPADDR
cacti   IN      A       $IPADDR
voip    IN      A       $IPADDR
cctv    IN      A       $IPADDR
_sip._udp.voip.$DOMAIN2.     86400       IN      SRV     10      5       5060        voip.$DOMAIN2.
EOF

# Konfigurasi named.conf.local
cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN1" {
        type master;
        file "/etc/bind/db.$DO1";
};

zone "$DOMAIN2" {
        type master;
        file "/etc/bind/db.$DO2";
};

zone "$REVERSED_IP.in-addr.arpa" {
        type master;
        file "/etc/bind/db.$i1";
};
EOF

# Konfigurasi named.conf.options
cat > /etc/bind/named.conf.options <<EOF
options {
        directory "/var/cache/bind";

        allow-query { 127.0.0.1; $NETWORK; };

        forwarders {
                8.8.8.8;
                8.8.4.4;
        };
        recursion yes;
        forward only;

        dnssec-validation no;

        listen-on-v6 { none; };
};
EOF

# Konfigurasi resolv.conf
sed -i 's/^nameserver/#nameserver/g' /etc/resolv.conf
echo "nameserver $IPADDR" >> /etc/resolv.conf

# Restart dan cek status BIND9
echo "----------------------------------------------------"
echo "Restart dan cek status BIND9"
echo "----------------------------------------------------"
systemctl restart bind9
systemctl status bind9
sleep 2

# Uji konfigurasi dengan nslookup
echo "----------------------------------------------------"
echo "Uji konfigurasi dengan nslookup"
echo "----------------------------------------------------"
nslookup www.$DOMAIN1
nslookup www.$DOMAIN2
sleep 2

# Install LAMP Stack
sleep 2
echo "----------------------------------------------------"
echo "Install LAMP Stack"
echo "----------------------------------------------------"
apt install apache2 php php-json php-mysql mariadb-server wget unzip expect -y

# Otomatis mysql_secure_installation menggunakan expect
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"\r\"

expect \"Switch to unix_socket authentication\"
send \"Y\r\"

expect \"Change the root password?\"
send \"Y\r\"

expect \"New password:\"
send \"antix\r\"

expect \"Re-enter new password:\"
send \"antix\r\"

expect \"Remove anonymous users?\"
send \"Y\r\"

expect \"Disallow root login remotely?\"
send \"Y\r\"

expect \"Remove test database and access to it?\"
send \"Y\r\"

expect \"Reload privilege tables now?\"
send \"Y\r\"

expect eof
")

echo "$SECURE_MYSQL"

DB1=$(echo "$DOMAIN1" | cut -d '.' -f 1)
DB2=$(echo "$DOMAIN2" | cut -d '.' -f 1)

# Buat database untuk domain 1
mysql -u root -pantix -e "CREATE DATABASE $DB1;"

# Buat database untuk domain 2
mysql -u root -pantix -e "CREATE DATABASE $DB2;"

# Download dan Install WordPress untuk domain 1
wget https://wordpress.org/latest.zip
unzip latest.zip
chmod -R 777 wordpress
mkdir /var/www/$DO1
mv wordpress/ /var/www/$DO1/

# Download dan Install WordPress untuk domain 2
unzip latest.zip
chmod -R 777 wordpress
mkdir /var/www/$DO2
mv wordpress/ /var/www/$DO2/

# Konfigurasi Apache untuk domain 1
cat > /etc/apache2/sites-available/www$DO1.conf <<EOF
<VirtualHost *:80>
    ServerName www.$DOMAIN1
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/$DO1/wordpress
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

cat > /etc/apache2/sites-available/$DO1.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN1
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/$DO1/wordpress
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Konfigurasi Apache untuk domain 2
cat > /etc/apache2/sites-available/www$DO2.conf <<EOF
<VirtualHost *:80>
    ServerName www.$DOMAIN2
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/$DO2/wordpress
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

cat > /etc/apache2/sites-available/$DO2.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN2
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/$DO2/wordpress
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Aktifkan konfigurasi situs
a2ensite www$DO1.conf
a2ensite $DO1.conf
a2ensite www$DO2.conf
a2ensite $DO2.conf

# Nonaktifkan situs default
a2dissite 000-default.conf

# Set konfigurasi otomatis untuk phpMyAdmin
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password antix" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password antix" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password antix" | debconf-set-selections

# Install phpMyAdmin
sleep 2
echo "----------------------------------------------------"
echo "Install phpMyAdmin"
echo "----------------------------------------------------"
apt install phpmyadmin -y

# Restart dan cek status Apache
echo "----------------------------------------------------"
echo "Restart dan cek status Apache"
echo "----------------------------------------------------"
systemctl restart apache2
systemctl status apache2
sleep 2

# Install Samba Server
sleep 2
echo "----------------------------------------------------"
echo "Install Samba Server"
echo "----------------------------------------------------"
apt install samba samba-client -y

# Input user dan nama folder
sleep 2
echo "----------------------------------------------------"
echo "Konfigurasi User dan Folder Samba"
echo "----------------------------------------------------"
read -p "Masukkan user untuk akses folder samba (contoh: samba-public): " USER_SAMBA
read -p "Masukkan nama folder untuk akses full sharing (baca dan tulis) (contoh: Sharing): " SHARING_FOLDER
read -p "Masukkan nama folder untuk akses read-only (hanya baca) (contoh: Aplikasi): " READONLY_FOLDER

# Buat user untuk akses folder Samba
/usr/sbin/useradd -rs /bin/false $USER_SAMBA

# Buat folder untuk user samba
mkdir /$SHARING_FOLDER
mkdir /$READONLY_FOLDER

# Set permission untuk folder samba
chown $USER_SAMBA /$SHARING_FOLDER
chown $USER_SAMBA /$READONLY_FOLDER
chmod u+rwx /$SHARING_FOLDER
chmod u+rx /$READONLY_FOLDER

# Konfigurasi Samba Server
cat >> /etc/samba/smb.conf <<EOF
[$SHARING_FOLDER]
    path = /$SHARING_FOLDER
    available = yes
    browsable = yes
    public = yes
    writable = yes
    force user = $USER_SAMBA

[$READONLY_FOLDER]
    path = /$READONLY_FOLDER
    available = yes
    browsable = yes
    public = yes
    writable = no
    force user = $USER_SAMBA
EOF

# Restart dan cek status Samba Server
echo "----------------------------------------------------"
echo "Restart dan cek status Samba Server"
echo "----------------------------------------------------"
systemctl restart smbd
systemctl status smbd
sleep 2

# Set konfigurasi postfix menggunakan debconf
export DEBIAN_FRONTEND=noninteractive
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $DOMAIN1" | debconf-set-selections
echo "postfix postfix/root_address string ''" | debconf-set-selections  # Mengosongkan root_address
echo "postfix postfix/destinations string $DOMAIN1, mail.$DOMAIN1, localhost" | debconf-set-selections
echo "postfix postfix/sync_update boolean true" | debconf-set-selections
echo "postfix postfix/mynetworks string 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 0.0.0.0/0" | debconf-set-selections
echo "postfix postfix/mailbox_size_limit string 0" | debconf-set-selections
echo "postfix postfix/recipient_delim string +" | debconf-set-selections
echo "postfix postfix/inet_protocols select ipv4" | debconf-set-selections

# Install Mail Server Postfix dan Dovecot
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Install Mail Server Postfix dan dovecot"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo -e "\e[1;34mSaat ditanya System Mail Name, Masukkan $DOMAIN1\e[0m"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
sleep 5
apt install postfix dovecot-imapd dovecot-pop3d -y

# Konfigurasi Postfix

# Edit /etc/postfix/main.cf
sed -i "s/^mydestination.*/mydestination = $DOMAIN1, mail.$DOMAIN1, localhost/" /etc/postfix/main.cf
sed -i "s/^mynetworks.*/mynetworks = 127.0.0.0\/8 [::ffff:127.0.0.0]\/104 [::1]\/128 0.0.0.0\/0/" /etc/postfix/main.cf
sed -i "s/^inet_protocols.*/inet_protocols = ipv4/" /etc/postfix/main.cf

#tambahkan home_mailbox
echo "home_mailbox = Maildir/" >> /etc/postfix/main.cf

# Buat mail directory di /etc/skel
maildirmake.dovecot /etc/skel/Maildir

#dpkg-reconfigure postfix

# Reconfigure postfix
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure postfix

# Konfigurasi Dovecot

# Edit /etc/dovecot/dovecot.conf
sed -i 's/^#listen = .*/listen = */' /etc/dovecot/dovecot.conf

# Edit /etc/dovecot/conf.d/10-auth.conf
sed -i 's/^#disable_plaintext_auth = .*/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf

# Edit /etc/dovecot/conf.d/10-mail.conf
sed -i '/^# *mail_location = maildir:~\/Maildir/s/^# *//' /etc/dovecot/conf.d/10-mail.conf
sed -i '/^mail_location = mbox:~\/mail:INBOX=\/var\/mail\/%u/s/^/#/' /etc/dovecot/conf.d/10-mail.conf

# Buat user untuk mail server
sleep 2
echo "----------------------------------------------------"
echo " User untuk Mail Sever"
echo "----------------------------------------------------"
read -p "Masukkan username 1 (contoh: vinic): " USER1_MAIL
read -p "Masukkan password 1 (contoh: vinic): " USER1_PASS
read -p "Masukkan username 2 (contoh: slamet): " USER2_MAIL
read -p "Masukkan password 2 (contoh: slamet): " USER2_PASS

adduser --disabled-password --gecos "" $USER1_MAIL
echo "$USER1_MAIL:$USER1_PASS" | chpasswd

adduser --disabled-password --gecos "" $USER2_MAIL
echo "$USER2_MAIL:$USER2_PASS" | chpasswd

# Restart dan cek status Postfix dan Dovecot
echo "----------------------------------------------------"
echo "Restart dan cek status Postfix dan Dovecot"
echo "----------------------------------------------------"
systemctl restart postfix dovecot
systemctl status postfix
systemctl status dovecot
sleep 2

# Set konfigurasi roundcube menggunakan debconf
export DEBIAN_FRONTEND=noninteractive
echo "roundcube-core roundcube/dbconfig-install boolean true" | debconf-set-selections
echo "roundcube-core roundcube/database-type select mysql" | debconf-set-selections
echo "roundcube-core roundcube/mysql/admin-pass password antix" | debconf-set-selections
echo "roundcube-core roundcube/mysql/app-pass password antix" | debconf-set-selections
echo "roundcube-core roundcube/mysql/app-pass-confirm password antix" | debconf-set-selections

# Set konfigurasi dpkg-reconfigure roundcube-core menggunakan debconf
echo "roundcube-core roundcube/remote-host string localhost:143" | debconf-set-selections
echo "roundcube-core roundcube/default-language select en_US" | debconf-set-selections
echo "roundcube-core roundcube/reconfigure-webserver select apache2" | debconf-set-selections
echo "roundcube-core roundcube/upgrade-backup boolean true" | debconf-set-selections
echo "roundcube-core roundcube/restart-webserver boolean true" | debconf-set-selections
echo "roundcube-core roundcube/purge boolean false" | debconf-set-selections

# Install Roundcube
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Install Roundcube"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo -e "\e[1;34mSaat ditanya password MYSQL, Masukkan antix\e[0m"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++"
sleep 5
apt install roundcube -y

# Konfigurasi Roundcube

# Edit /etc/roundcube/config.inc.php
sed -i "s/\$config\['imap_host'\].*/\$config\['imap_host'\] = \['$DOMAIN1:143'\];/" /etc/roundcube/config.inc.php
sed -i "s/\$config\['smtp_host'\].*/\$config\['smtp_host'\] = '$DOMAIN1:25';/" /etc/roundcube/config.inc.php
sed -i "s/\$config\['smtp_user'\] = '%u';/\$config\['smtp_user'\] = '';/" /etc/roundcube/config.inc.php
sed -i "s/\$config\['smtp_pass'\] = '%p';/\$config\['smtp_pass'\] = '';/" /etc/roundcube/config.inc.php
sed -i "s/\$config\['product_name'\] = 'Roundcube Webmail';/\$config\['product_name'\] = 'Selamat datang di Webmail $DOMAIN1';/" /etc/roundcube/config.inc.php

#dpkg-reconfigure roundcube-core

# Jalankan dpkg-reconfigure untuk memastikan konfigurasi diterapkan
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure roundcube-core

# Konfigurasi Apache untuk Mail Server
cat > /etc/apache2/sites-available/mail$DO1.conf <<EOF
<VirtualHost *:80>
    ServerName mail.$DOMAIN1
    ServerAdmin webmaster@localhost
    DocumentRoot /usr/share/roundcube
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Aktifkan konfigurasi situs
a2ensite mail$DO1.conf

# Restart dan cek status Apache
echo "----------------------------------------------------"
echo "Restart dan cek status Apache"
echo "----------------------------------------------------"
systemctl restart apache2 
systemctl status apache2
sleep 2

# Limit attachment file 20 MB
sleep 2
echo "----------------------------------------------------"
echo "Limit attachment file"
echo "----------------------------------------------------"
read -p "Limit attachment file MB (contoh: 20): " LIMIT_FILE

# Edit /etc/php/8.2/apache2/php.ini
sed -i "s/^upload_max_filesize = .*/upload_max_filesize = ${LIMIT_FILE}M/" /etc/php/8.2/apache2/php.ini
sed -i "s/^post_max_size = .*/post_max_size = ${LIMIT_FILE}M/" /etc/php/8.2/apache2/php.ini

# tambahkan message_size_limit
echo "message_size_limit = ${LIMIT_FILE}480000" >> /etc/postfix/main.cf

# Restart dan cek status Apache, Postfix, dan Dovecot
echo "----------------------------------------------------"
echo "Restart dan cek status Apache, Postfix, dan Dovecot"
echo "----------------------------------------------------"
systemctl restart apache2 postfix dovecot
systemctl status apache2
systemctl status postfix
systemctl status dovecot
sleep 3

########## CACTI ########## CACTI ########## CACTI ########## CACTI ########## CACTI ########## 
########## CACTI ########## CACTI ########## CACTI ########## CACTI ########## CACTI ########## 
########## CACTI ########## CACTI ########## CACTI ########## CACTI ########## CACTI ##########

sudo timedatectl set-timezone Asia/Jakarta
echo "----------------------------------------------------"
echo " START INSTALL CACTI TERBARU DEBIAN 12 "
echo "----------------------------------------------------"
sleep 2
echo ""
echo "----------------------------------------------------"
echo " update dan upgrade "
echo "----------------------------------------------------"
apt update && apt upgrade -y

sleep 2
echo "----------------------------------------------------"
echo "Install Paket pendukung Cacti"
echo "----------------------------------------------------"
apt install cron snmp snmpd php-snmp rrdtool librrds-perl unzip curl git gnupg2 -y

sleep 2
echo "----------------------------------------------------"
echo "Install LAMP Server"
echo "----------------------------------------------------"
apt install apache2 mariadb-server php php-mysql libapache2-mod-php php-xml php-ldap php-mbstring php-gd php-gmp php-intl -y

sleep 2
echo "----------------------------------------------------"
echo "Config Apache"
echo "----------------------------------------------------"

sleep 2
sed -i 's/memory_limit = 128M/memory_limit = 1024M/g' /etc/php/8.2/apache2/php.ini

sed -i 's/max_execution_time = 30/max_execution_time = 60/g' /etc/php/8.2/apache2/php.ini

sed -i 's/;date.timezone =/date.timezone = Asia\/Jakarta/g' /etc/php/8.2/apache2/php.ini

sed -i 's/memory_limit = 128M/memory_limit = 1024M/g' /etc/php/8.2/cli/php.ini

sed -i 's/max_execution_time = 30/max_execution_time = 60/g' /etc/php/8.2/cli/php.ini

sed -i 's/;date.timezone =/date.timezone = Asia\/Jakarta/g' /etc/php/8.2/cli/php.ini

systemctl restart apache2

echo "----------------------------------------------------"
echo "Config MySQL"
echo "----------------------------------------------------"

sleep 2
sed -i 's/collation-server      = utf8mb4_general_ci/collation-server      = utf8mb4_unicode_ci/g' /etc/mysql/mariadb.conf.d/50-server.cnf

cat >> /etc/mysql/mariadb.conf.d/50-server.cnf << EOF
max_heap_table_size = 128M
tmp_table_size = 128M
join_buffer_size = 1M
innodb_file_format = Barracuda
innodb_large_prefix = 1
innodb_buffer_pool_size = 2048M
innodb_flush_log_at_timeout = 3
innodb_read_io_threads = 32
innodb_write_io_threads = 16
innodb_io_capacity = 5000
innodb_io_capacity_max = 10000
innodb_doublewrite = OFF
sort_buffer_size = 1M
EOF

systemctl restart mariadb

echo "----------------------------------------------------"
echo "  Nama Database  "
echo "----------------------------------------------------"
sleep 2

read -p "contoh cactidb: " namadb

mysqladmin -uroot create $namadb

echo "----------------------------------------------------"
echo "  Password Database  "
echo "----------------------------------------------------"
sleep 2

read -p "masukkan password untuk database, contoh cactidb: " passdb

mysql -uroot -e "grant all on $namadb.* to 'cactiuser'@'localhost' identified by '$passdb'"

mysql -uroot -e "flush privileges"

mysql mysql < /usr/share/mysql/mysql_test_data_timezone.sql

mysql -uroot -e "GRANT SELECT ON mysql.time_zone_name TO 'cactiuser'@'localhost'"

mysql -uroot -e "flush privileges"

rm -rf /var/www/html/index.html

echo "----------------------------------------------------"
echo " download cacti versi terbaru "
echo "----------------------------------------------------"
sleep 2

wget http://repo.antix.or.id/other/cacti-latest.tar.gz --no-check-certificate

echo "----------------------------------------------------"
echo " Ekstrak Cacti "
echo "----------------------------------------------------"
sleep 2

tar -zxvf cacti-latest.tar.gz

echo "----------------------------------------------------"
echo " Copy Cacti ke Folder /var/www/html"
echo "----------------------------------------------------"
sleep 2

cp -a cacti-1*/. /var/www/html

chown -R www-data:www-data /var/www/html/

chmod -R 775 /var/www/html/

mysql $namadb < /var/www/html/cacti.sql

cp /var/www/html/include/config.php.dist /var/www/html/include/config.php

sed -i 's/database_default  = '\''cacti/database_default  = '\'''$namadb'/g' /var/www/html/include/config.php

sed -i 's/database_password = '\''cactiuser/database_password = '\'''$passdb'/g' /var/www/html/include/config.php

sed -i 's/url_path = '\''\/cacti/url_path = '\''/g' /var/www/html/include/config.php

echo "----------------------------------------------------"
echo " Tambah cacti di cronjob"
echo "----------------------------------------------------"
sleep 2
touch /etc/cron.d/cacti
cat >> /etc/cron.d/cacti << EOF
*/5 * * * * www-data php /var/www/html/poller.php > /dev/null 2>&1
EOF

chmod +x /etc/cron.d/cacti

# Buat nama string untuk SNMP
sleep 2
echo "----------------------------------------------------"
echo " Buat nama string untuk SNMP"
echo "----------------------------------------------------"
read -p "Masukkan Community String (contoh: tkj): " COSTRING

# Konfigurasi SNMP
sed -i 's/^agentaddress[[:space:]]*127.0.0.1,\[::1\]/#agentaddress 127.0.0.1,[::1]/g' /etc/snmp/snmpd.conf
echo "agentaddress $IPADDR" >> /etc/snmp/snmpd.conf

sed -i 's/^rocommunity[[:space:]]*public[[:space:]]*default[[:space:]]*-V[[:space:]]*systemonly/#rocommunity public default -V systemonly/g' /etc/snmp/snmpd.conf
sed -i 's/^rocommunity6[[:space:]]*public[[:space:]]*default[[:space:]]*-V[[:space:]]*systemonly/#rocommunity6 public default -V systemonly/g' /etc/snmp/snmpd.conf

echo "rocommunity $COSTRING $IPADDR" >> /etc/snmp/snmpd.conf

# Restart dan cek status SNMP
echo "----------------------------------------------------"
echo "Restart dan cek status SNMP"
echo "----------------------------------------------------"
systemctl restart snmpd.service 
systemctl status snmpd.service
sleep 2

# Informasi device
snmpwalk -v2c -c $COSTRING $IPADDR

# Konfigurasi Apache untuk Cacti Server
cat > /etc/apache2/sites-available/cacti$DO2.conf <<EOF
<VirtualHost *:80>
    ServerName cacti.$DOMAIN2
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Aktifkan konfigurasi situs
a2ensite cacti$DO2.conf

# Restart dan cek status Apache
echo "----------------------------------------------------"
echo "Restart dan cek status Apache"
echo "----------------------------------------------------"
systemctl restart apache2 
systemctl status apache2
sleep 2

echo "===================================================="
echo -e "\e[1;31m+++++INFORMASI PENTING+++++\e[0m"
echo -e "\e[1;32mSilakan akses http://www.$DOMAIN1 dan http://www.$DOMAIN2\e[0m"
echo -e "\e[1;34mNama database untuk www.$DOMAIN1: $DB1 dan www.$DOMAIN2: $DB2\e[0m"
echo -e "\e[1;31mUser "root" dan Password "antix"\e[0m"
echo "Untuk Mengakses samba sharing folder di file explorer windows \\\\$IPADDR dan di file explorer MX Linux smb:\\\\$IPADDR"
echo -e "\e[1;31mhttp://mail.$DOMAIN1 untuk mengakses Roundcube Webmail\e[0m"
echo -e "\e[1;32mUser mail 1: $USER1_MAIL dengan Password $USER1_PASS dan User mail 2: $USER2_MAIL dengan Password $USER2_PASS\e[0m"
echo "===================================================="
echo " Cacti terinstall di folder /var/www/html "
echo " Silahkan lanjutkan login cacti http://"`hostname -I | awk '{print $1}'`
echo " Atau langsung saja melalui domain http://cacti.$DOMAIN2 "
echo " Username: admin dan password: admin "
echo " Community String: $COSTRING "
echo "===================================================="
echo -e "\e[1;32mJangan Lupa untuk mengganti DNS di PC/Laptop Menjadi $IPADDR\e[0m"
echo "===================================================="
echo -e "\e[1;34m+++++vinic+++++\e[0m"
echo "===================================================="
sleep 3
