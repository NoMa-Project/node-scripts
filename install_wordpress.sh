#!/bin/bash
#this script creates n number of website (wordpress + database + link both + https)
#param : sitename, db_name, db_user, db_password, localhost (if db is not on localhost)

apt update 
apt upgrade -y
apt install apache2 ghostscript libapache2-mod-php mysql-server php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip -y
data=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

sudo ufw allow "Apache Full"
sudo a2enmod ssl
sudo systemctl restart apache2

#get necessary informations from user
echo "Sitename cannot be wordpress."
read -p "Entrez le nom de votre site: " sitename
read -p "Entrez le nom de la base de données: " db_name
read -p "Entrez le nom d'utilisateur de la base de données: " db_user
read -s -p "Entrez le mot de passe de la base de données: " db_password

#create ssl key and certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/$sitename.key -out /etc/ssl/certs/$sitename.crt
#enter ip when asked common name or sitename.com

echo "<VirtualHost *:443>" >> /etc/apache2/sites-available/$sitename.conf
echo "   ServerName $sitename.com" >> /etc/apache2/sites-available/$sitename.conf
echo "   DocumentRoot /var/www/$sitename" >> /etc/apache2/sites-available/$sitename.conf

echo "   SSLEngine on" >> /etc/apache2/sites-available/$sitename.conf
echo "   SSLCertificateFile /etc/ssl/certs/$sitename.crt" >> /etc/apache2/sites-available/$sitename.conf
echo "   SSLCertificateKeyFile /etc/ssl/private/$sitename.key" >> /etc/apache2/sites-available/$sitename.conf
echo "</VirtualHost>" >> /etc/apache2/sites-available/$sitename.conf

#download and install wordpress
wget https://wordpress.org/latest.tar.gz
tar -xvzf latest.tar.gz
mv wordpress /var/www/$sitename
rm -rf latest.tar.gz
chown -R www-data:www-data /var/www/wordpress
cp -r /var/www/wordpress /var/www/$sitename
rm -rf /var/www/wordpress
sudo chmod -R 755 /var/www/$sitename

sudo a2ensite $sitename.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
sudo ufw allow "Apache Full"

#configuration of apache for wordpress
echo "<VirtualHost *:80>
  ServerName $sitename.com
  ServerAlias www.$sitename.com/
  DocumentRoot /var/www/$sitename/
<Directory /var/www/$sitename>
  Options FollowSymLinks
  AllowOverride Limit Options FileInfo
  DirectoryIndex index.php
  Require all granted
</Directory>
<Directory /var/www/$sitename/wp-content>
  Options FollowSymLinks
  Require all granted
</Directory>
</VirtualHost>" >> /etc/apache2/sites-available/$sitename.conf

#activate new site
a2ensite $sitename

#config hosts file
myip=$(ip a s dev ens33 | awk '/inet /{print $2}' | cut -d/ -f1)
echo "$myip $sitename.com" >> /etc/hosts
a2dissite 000-default
systemctl restart apache2
ufw allow "Apache Full"

#configuration of database for wordpress
mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE $db_name;
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

#create wordpress configuration file
echo "<?php" >> /var/www/$sitename/wp-config.php

#configuration of wordpress to use this database
echo "define( 'DB_NAME', '$db_name' );
define( 'DB_USER', '$db_user' );
define( 'DB_PASSWORD', '$db_password' );" >> /var/www/$sitename/wp-config.php
#attention : remplacer localhost par l'ip de la machine qui heberge la db
echo "define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
$data
\$table_prefix = 'wp_';
define( 'WP_DEBUG', false );
if ( ! defined( 'ABSPATH' ) ) { define( 'ABSPATH', __DIR__ . '/' ); }
require_once ABSPATH . 'wp-settings.php';
?>" >> /var/www/$sitename/wp-config.php

echo "Le site web $sitename.com a été créé avec succès !"
