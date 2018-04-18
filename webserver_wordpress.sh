#!/bin/bash
# Step 1 change domain name
echo Hello, Please enter the Domain name ::
read domainname
echo You have entered doamin name as $domainname
echo "$domainname" >> /etc/resolvconf/resolv.conf.d/head
resolvconf -u
hostname=$(hostname)
echo hostname is $hostname
#echo "127.0.0.1 $hostname.$domainname $hostname" >> /etc/hosts
#sed -i 's/$hostname/$domainname/g' /etc/hosts
sed -i "s/$hostname/$domainname/g" /etc/hosts
sed -i "s/$hostname/$domainname/g" /etc/hostname
#echo "$domainname" >> /etc/hostname
echo "***** Domain name has been set as $domainname **********"

sleep 3
# Step 2 installing packages

echo "****************** To check Packages installed or not if not then Install *********************************"

echo "********************Updating all packages*****************"
        apt-get update

for var in nginx php* php-mbstring php-xmlrpc php-soap php-gd php-xml php-intl php-mysql php-cli php-mcrypt php-ldap php-zip php-curl php-fpm
do
 if dpkg-query -Wf'${db:Status-abbrev}' "$var" 2>/dev/null | grep -q '^i'; then
     printf 'The package "%s" is already installed!\n' "$var"
 else
     printf 'Instaling package "%s"\n' "$var"
        apt-get install $var -y;
 fi
done

echo "****** Setting up MySQL server installation *************"
if dpkg-query -Wf'${db:Status-abbrev}' "mysql-server" 2>/dev/null | grep -q '^i'; then
     printf 'The package "%s" is already installed!\n' "mysql"
 else
     printf 'Instaling package "%s".\n' "mysql-server"

mysql_pass=root123
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< 'mysql-server mysql-server/root_password password '$mysql_pass''
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password '$mysql_pass''
	apt-get install mysql-server -y;

sleep 5
mysql -uroot -p$mysql_pass -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '"$mysql_pass"'; FLUSH PRIVILEGES;"
#Restart
systemctl restart mysql
echo "***************  MySQL Installation and Configuration is Complete. username=root password=root123  *************"
fi

echo "************************ All required packages are installed **************************************************"
sleep 3
# Step 3 Creation of DB

echo "********* Create a new Mysql database for WordPress with name 'example.com_db' *************"
#echo Please set test user passowrd for 'example.com_db' DB
#read test_user_pass
mysql -uroot -p$mysql_pass -e "CREATE DATABASE \`example.com_db\`;"
mysql -uroot -p$mysql_pass -e "CREATE USER 'test'@'localhost' IDENTIFIED BY 'test123';"
mysql -uroot -p$mysql_pass -e "GRANT ALL ON \`example.com_db\`.* TO 'test'@'localhost' IDENTIFIED BY 'test123'; FLUSH PRIVILEGES;"
#mysql -uroot -p$test_user_pass -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '"$test_user_pass"'; FLUSH PRIVILEGES;"

echo "************* DB creation done with name 'example.com_db' with username=test password=test123 ****************"
sleep 3
# Step 4 Wordpress download and setup

echo "*********************Downloading wordpress****************"
cd /tmp/ && wget http://wordpress.org/latest.tar.gz --no-check-certificate
tar -xvzf latest.tar.gz
sleep 5
cp -a /tmp/wordpress/. /var/www/html/
sleep 3
rm -rf /etc/nginx/sites-available/*
echo '
server {
    listen 80;
    listen [::]:80;
    root /var/www/html;
    index  index.php index.html index.htm;
    server_name  example.com www.example.com;

    location / {
    try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
    fastcgi_split_path_info  ^(.+\.php)(/.+)$;
    fastcgi_index            index.php;
    fastcgi_pass             unix:/run/php/php7.0-fpm.sock;
    include                  fastcgi_params;
    fastcgi_param   PATH_INFO       $fastcgi_path_info;
    fastcgi_param   SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

}
' >> /etc/nginx/sites-available/wordpress
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/

echo "*************** Wordpress configuration started ***************"

cd /var/www/html/
cp -r /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i 's/database_name_here/'example.com_db'/g' /var/www/html/wp-config.php
sed -i 's/username_here/root/g' /var/www/html/wp-config.php
#sed -i 's/password_here/'root123'/g' /var/www/html/wp-config.php
sed -i 's/password_here/'$mysql_pass'/g' /var/www/html/wp-config.php
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html/

#Restarting php and nginx
echo "****chaecking syntax and restarting servies******"
nginx -t
nginx -s reload
systemctl restart nginx.service
/etc/init.d/php7.0-fpm restart

echo "*************************************All Installation and Configuration done****************************************"
sleep 3
echo "
***********************************************************************************************************************************************
Please open example.com OR www.example.com OR localhost OR http://example.com/wp-admin/install.php OR http://SERVER_IP:80 for Wordpress website
*********************************************************************************************************************************************** "

