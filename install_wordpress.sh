#!/bin/bash
# This script can create a WordPress website (including database setup, linking, and HTTPS)
# Parameters: sitename, db_name, db_user, db_password, localhost (if db is not on localhost)

set -e

# Update and upgrade system
apt update && apt upgrade -y

# Install required packages
apt install apache2 ghostscript libapache2-mod-php mysql-server php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip -y

# Install WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Enable firewall
ufw allow "Apache Full"

# Enable SSL
a2enmod ssl
systemctl restart apache2

# Get necessary information from user
echo "Sitename cannot be 'wordpress'."
read -p "Enter the name of your site: " sitename
read -p "Enter the domain name: " fqdn
read -p "Enter the database name: " db_name
read -p "Enter the database username: " db_user
read -s -p "Enter the database password: " db_password
echo

# Create SSL key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/$sitename.key -out /etc/ssl/certs/$sitename.crt

# Create Apache virtual host configuration
cat << EOF > /etc/apache2/sites-available/$sitename.conf
<VirtualHost *:80>
    ServerName $fqdn
    ServerAlias www.$fqdn
    DocumentRoot /var/www/$sitename/

    <Directory /var/www/$sitename/>
        Options FollowSymLinks
        AllowOverride Limit
        DirectoryIndex index.php
        Require all granted
    </Directory>

    <Directory /var/www/$sitename/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:443>
    ServerName $fqdn
    DocumentRoot /var/www/$sitename/
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/$sitename.crt
    SSLCertificateKeyFile /etc/ssl/private/$sitename.key

    <Directory /var/www/$sitename/>
        Options FollowSymLinks
        AllowOverride Limit
        DirectoryIndex index.php
        Require all granted
    </Directory>

    <Directory /var/www/$sitename/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Enable the site
a2ensite $sitename.conf

# Update hosts file
myip=$(ip a s dev ens33 | awk '/inet /{print $2}' | cut -d/ -f1)
echo "$myip $fqdn" >> /etc/hosts

# Restart Apache
systemctl restart apache2

# Create database and user
mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS $db_name;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';
ALTER USER '$db_user'@'localhost' IDENTIFIED WITH mysql_native_password BY '$db_password';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Download and install WordPress
mkdir /var/www/$sitename/ 
cd /var/www/$sitename/
wp core download --allow-root
wp config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_password --dbhost=localhost --skip-check --allow-root

# Auto-install WordPress
wp core install --url=$fqdn --title="$sitename" --admin_user=admin --admin_password=admin_password --admin_email=admin@$fqdn --skip-email --allow-root

# Set ownership and permissions
chown -R www-data:www-data /var/www/$sitename/
chmod -R 755 /var/www/$sitename/

echo "The website $fqdn has been successfully created!"
echo "Wordpress Credentials = User : admin  Password : admin_password Email : admin@$fqnd"
