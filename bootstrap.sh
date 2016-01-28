#!/bin/bash
function pretty_print {
  echo -e "\e[32m${1}\e[0m"
}

# Update System
pretty_print 'Update System'
sudo apt-get update > /dev/null 2>&1
sudo apt-get -y install zip vim > /dev/null 2>&1

# Install NginX
pretty_print 'Install NginX'
sudo apt-get -y install nginx > /dev/null 2>&1

# Install MySQL Server
pretty_print 'Install mysql-server'
apt-get -y install debconf-utils > /dev/null 2>&1
PASSWORD="1234"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $PASSWORD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $PASSWORD"
apt-get -y install mysql-server > /dev/null 2>&1
mysql -uroot -p$PASSWORD -e "SET PASSWORD = PASSWORD('');" > /dev/null 2>&1

# Install PHP
pretty_print 'Install PHP'
sudo apt-get -y install php5-fpm php5-mysql > /dev/null 2>&1
sudo apt-get -y install php5-mcrypt php5-mysqlnd > /dev/null 2>&1

# Configure NginX and PHP5-FPM
pretty_print 'Configure NginX'
rm -f /etc/nginx/sites-available/default
cat << _EOF | tee -a /etc/nginx/sites-available/default > /dev/null 2>&1
# You may add here your
# server {
#       ...
# } 
# statements for each of your virtual hosts to this file 
##

server {
	listen 80 default_server;
	listen [::]:80 default_server ipv6only=on;

	root /usr/share/nginx/html;
	index index.php index.html index.htm;

	server_name 192.168.33.12;

	location / {
		try_files \$uri \$uri/ =404;
	}

	error_page 404 /404.html;
	error_page 500 502 503 504 /50x.html;

	location = /50x.html{
		root /usr/share/nginx/html;
	}

	location ~ \.php$ {
		fastcgi_split_path_info ^(.+\.php)(\.+)$;
		fastcgi_pass unix:/var/run/php5-fpm.sock;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		fastcgi_index index.php;
		include fastcgi_params;
	}
}
_EOF
pretty_print 'Configuring PHP5-FPM'
sudo sed -i 's/max_execution_time = 30/max_execution_time = 120/g' /etc/php5/fpm/php.ini
sudo sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/fpm/php.ini
sudo php5enmod mcrypt

# Restart Services
service nginx restart > /dev/null 2>&1
service php5-fpm restart > /dev/null 2>&1

# Get and place Teampass
pretty_print 'Preparing Teampass'
cd /tmp
wget https://codeload.github.com/nilsteampassnet/TeamPass/zip/2.1.24.4 > /dev/null 2>&1
unzip 2.1.24.4 > /dev/null 2>&1
rm -f /usr/share/nginx/html/*
cp -r TeamPass-2.1.24.4/* /usr/share/nginx/html
cd /usr/share/nginx
mkdir /usr/share/nginx/html/keys
chmod 777 -R /usr/share/nginx/html

# Prepare Teampass Database
sql_host="localhost"
sql_usuario="root"
sql_args="-h $sql_host -u $sql_usuario -s -e"
mysql $sql_args "create database teampassdb;"
mysql $sql_args "grant all privileges on teampassdb.* to teampassadmin@'$sql_host' identified by '1234';"
mysql $sql_args "grant all privileges on teampassdb.* to teampassadmin@'%' identified by '1234';"
