#!/bin/bash
#laravel install

apt update -y && apt upgrade -y
apt install -y zip curl lsb-release apt-transport-https ca-certificates
add-apt-repository -y ppa:ondrej/php
apt install -y php8.1 php8.1-fpm php8.1-mysql php8.1-pgsql php8.1-sqlite3 php8.1-bcmath php8.1-mbstring php8.1-xml php8.1-curl php8.1-zip php8.1-gd

apt install apache2 mysql-server libapache2-mod-php8.1 -y

#get necessary informations from user
read -p "Entrez le nom de votre site: " sitename
read -p "Entrez le nom de dommaine: " fqnd
read -p "Entrez le nom de la base de données: " db_name
read -p "Entrez le nom d'utilisateur de la base de données: " db_user
read -s -p "Entrez le mot de passe de la base de données: " db_password

#create database
mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE $db_name;
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

#create ssl key and certificate
sudo a2enmod ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/$sitename.key -out /etc/ssl/certs/$sitename.crt
#enter ip when asked common name or sitename.com

#install composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '55ce33d7678c5a611085589f1f3ddf8b3c52d662cd01d4ba75c0ee0459970c2200a51f492d557530c71c15d8dba01eae') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/local/bin/composer

#get laravel from github
git clone https://github.com/NoMa-Project/panel.git
cd ./NoMa
cd ..
cp -r NoMa /var/www/$sitename
rm -rf NoMa

cd /var/www/$sitename
composer install
apt install npm -y && npm install -y

#config apache
echo "<VirtualHost *:443>
   ServerName $fqnd
   DocumentRoot /var/www/$sitename/public
   SSLEngine on
   SSLCertificateFile /etc/ssl/certs/$sitename.crt
   SSLCertificateKeyFile /etc/ssl/private/$sitename.key
</VirtualHost>

<VirtualHost *:80>
    ServerName $fqnd
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/$sitename/public
    
    <Directory /var/www/$sitename/public/>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" >> /etc/apache2/sites-available/$sitename.conf

#handle the rights
chmod -R 755 /var/www/$sitename
chown -R www-data:www-data /var/www/$sitename
a2enmod rewrite
a2dissite 000-default.conf
a2ensite $sitename.conf
systemctl restart apache2

#config file of laravel
cp .env.example .env
#php artisan serve
php artisan key:generate

#config hosts file
myip=$(ip a s dev ens33 | awk '/inet /{print $2}' | cut -d/ -f1)
echo "$myip $fqnd" >> /etc/hosts

#config .env file
sed -i "s/^DB_DATABASE=.*/DB_DATABASE=test1/" /var/www/$sitename/.env
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=test1/" /var/www/$sitename/.env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=password/" /var/www/$sitename/.env

php artisan migrate
clear
echo "Installation completed. Enter https://$fqnd in your naviguator to access your website."
