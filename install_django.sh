#!/bin/bash
#this script can create n number of website (django + database + link both + https) #param : sitename, db_name, db_user, db_password
apt update && apt upgrade -y
apt install apache2 libapache2-mod-wsgi-py3 -y systemctl start apache2
systemctl enable apache2
ufw allow "Apache Full"
a2enmod ssl
systemctl restart apache2
#get necessary informations from user
echo "Sitename cannot be wordpress."
read -p "Entrez le nom de votre site: " sitename
read -p "Entrez le nom de dommaine: " fqnd
read -p "Entrez le nom de votre projet: " projectname
read -p "Entrez le nom de la base de données: " db_name
read -p "Entrez le nom d'utilisateur de la base de données: " db_user 
read -s -p "Entrez le mot de passe de la base de données: " db_password
#create ssl key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/$sitename.key -out /etc/ssl/certs/$sitename.crt
#enter yourSitename.com when asked common name
#configuration apache
echo "<VirtualHost *:80>
        ServerName $fqnd
ServerAlias www.$fqnd
        Redirect / https://$fqnd
</VirtualHost>
<VirtualHost *:443>
ServerName $fqnd DocumentRoot /var/www/$sitename
SSLEngine on
SSLCertificateFile /etc/ssl/certs/$sitename.crt SSLCertificateKeyFile /etc/ssl/private/$sitename.key
Alias /media /var/www/$sitename/media <Directory /var/www/$sitename/$projectname>
                 <Files wsgi.py>
                        Require all granted
                </Files>
        </Directory>
WSGIDaemonProcess $projectname python-path=/var/www/$sitename python- home=/var/www/$sitename/django_env
WSGIProcessGroup $projectname
WSGIScriptAlias / /var/www/$sitename/$projectname/wsgi.py </VirtualHost>" >> /etc/apache2/sites-available/$sitename.conf
#install database
apt install mysql-server libmysqlclient-dev -y
 systemctl start mysql
systemctl enable mysql
mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE $db_name;
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password'; GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost'; FLUSH PRIVILEGES;
MYSQL_SCRIPT
#install pip & venv
apt install python3-venv python3-pip -y
#install django using virtualenv
mkdir /var/www/$sitename
cd /var/www/$sitename
python3 -m venv django_env source django_env/bin/activate pip install django
pip install mysqlclient
#configuration hosts file
myip=$(ip a s dev ens33 | awk '/inet /{print $2}' | cut -d/ -f1) echo "$myip $fqnd" >> /etc/hosts
 #create django project
django-admin startproject $projectname .
sed -i '/^ALLOWED_HOSTS/d' /var/www/$sitename/$projectname/settings.py echo "ALLOWED_HOSTS = ['127.0.0.1', '$myip', '$fqnd']" >> /var/www/$sitename/$projectname/settings.py
sed -i '/^DATABASES = {/,/^}/d' /var/www/$sitename/$projectname/settings.py echo "DATABASES = {
'default': {

'ENGINE': 'django.db.backends.mysql', 'NAME': '$db_name',
'USER': '$db_user',
'PASSWORD': '$db_password',
  'HOST': '127.0.0.1',
  'PORT' : '3306',
  }
}
import os
STATIC_URL='/static/' STATIC_ROOT=os.path.join(BASE_DIR, 'static/')
MEDIA_URL='/media/'
MEDIA_ROOT=os.path.join(BASE_DIR, 'media/')" >> /var/www/$sitename/$projectname/settings.py
#migrate the initial db schema to our mysql db
./manage.py makemigrations ./manage.py migrate
#create admin for the project
./manage.py createsuperuser #admin
#email
#password
./manage.py collectstatic deactivate
a2dissite 000-default.conf
a2ensite $sitename.conf
systemctl restart apache2
echo "Website $sitename successfully created !"
echo "Enter https://$fqnd to connect to your website."
