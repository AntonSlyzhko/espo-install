#!/bin/bash

# Basic packages installation
sudo apt update && sudo apt upgrade -y
sudo apt install curl ca-certificates apt-transport-https gnupg2 lsb-release ubuntu-keyring nginx mariadb-server unzip -y
sudo apt install php php-fpm php-mysql php-json php-imap php-gd php-zip php-mbstring php-curl php-xml php-bcmath php-ldap php-zmq -y
sudo phpenmod imap mbstring

# Define php version for future usage
php_version=$(php -r 'echo PHP_VERSION;' | awk -F. '{print $1"."$2}')

sudo sed -i 's/^max_execution_time =.*$/max_execution_time = 180/' "/etc/php/$php_version/cli/php.ini"
sudo sed -i 's/^max_execution_time =.*$/max_execution_time = 180/' "/etc/php/$php_version/fpm/php.ini"

sudo sed -i 's/^max_input_time =.*$/max_input_time = 180/' "/etc/php/$php_version/cli/php.ini"
sudo sed -i 's/^max_input_time =.*$/max_input_time = 180/' "/etc/php/$php_version/fpm/php.ini"

sudo sed -i 's/^memory_limit =.*$/memory_limit = 256M/' "/etc/php/$php_version/cli/php.ini"
sudo sed -i 's/^memory_limit =.*$/memory_limit = 256M/' "/etc/php/$php_version/fpm/php.ini"

sudo sed -i 's/^post_max_size =.*$/post_max_size = 128M/' "/etc/php/$php_version/cli/php.ini"
sudo sed -i 's/^post_max_size =.*$/post_max_size = 128M/' "/etc/php/$php_version/fpm/php.ini"

sudo sed -i 's/^upload_max_filesize =.*$/upload_max_filesize = 128M/' "/etc/php/$php_version/cli/php.ini"
sudo sed -i 's/^upload_max_filesize =.*$/upload_max_filesize = 128M/' "/etc/php/$php_version/fpm/php.ini"

# Core services setup
sudo systemctl start nginx.service && sudo systemctl enable nginx.service 
sudo systemctl start mariadb.service && sudo systemctl enable mariadb.service
sudo systemctl start php$php_version-fpm.service && sudo systemctl enable php$php_version-fpm.service

# Configure DB 
mysql_secure_installation

# Generate random password
DB_USER_PASS=$(openssl rand -base64 25 | tr -dc '[:alnum:]!@#$%^&*()-_+=' | head -c 25)

# Create database along with user with full access to the database
SQL_COMMAND="DROP DATABASE IF EXISTS espocrmdb; CREATE DATABASE espocrmdb; GRANT ALL ON espocrmdb.* TO espocrmuser@localhost IDENTIFIED BY '$DB_USER_PASS' WITH GRANT OPTION; FLUSH PRIVILEGES;"
sudo mariadb --user=root -e "$SQL_COMMAND"

MARIADB_CONFIG="
max_connections = 200
table_definition_cache = 800
table_open_cache = 4000
innodb_flush_method = O_DIRECT
innodb_log_file_size = 2G
innodb_flush_log_at_trx_commit = 2
"
echo "$MARIADB_CONFIG" | sudo tee -a "/etc/mysql/mariadb.conf.d/50-server.cnf" > /dev/null

# Fetch the latest EspoCRM release URL of the zip asset
zip_url=$(curl -s "https://api.github.com/repos/espocrm/espocrm/releases/latest" | grep "browser_download_url" | cut -d '"' -f 4)

folder_name=$(basename "$(echo $zip_url | xargs basename)" .zip)

# Download the zip asset
sudo curl -L -o /var/www/espocrm.zip "$zip_url"

sudo unzip -qq /var/www/espocrm.zip -d /var/www

sudo mv /var/www/$folder_name /var/www/espocrm
sudo mkdir -p /var/www/espocrm/data/logs
sudo mkdir -p /var/www/espocrm/client/custom/
sudo mkdir -p /var/www/espocrm/custom/Espo/Custom
# Copy service files to systemd
sudo cp espocrm-daemon.service /etc/systemd/system/espocrm-daemon.service
sudo cp espocrm-websocket.service /etc/systemd/system/espocrm-websocket.service

sudo systemctl daemon-reload
sudo systemctl enable espocrm-daemon.service
sudo systemctl start espocrm-daemon.service
sudo systemctl enable espocrm-websocket.service
sudo systemctl start espocrm-websocket.service
sudo systemctl restart mariadb

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt

SELF_SIGNED_CERT="
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
"
sudo touch /etc/nginx/snippets/self-signed.conf

echo "$SELF_SIGNED_CERT" | sudo tee -a "/etc/nginx/snippets/self-signed.conf" > /dev/null

# Create Nginx site config
nginx_conf_file_path="/etc/nginx/sites-available/espocrm.conf"
sudo cp espocrm.conf $nginx_conf_file_path
read -p "Enter the domain name: " domain_name

sudo sed -i "s/DOMAIN_NAME/$domain_name/g" "$nginx_conf_file_path"
sudo sed -i "s/PHP_VERSION/$php_version/g" "$nginx_conf_file_path"
sudo ln -sf $nginx_conf_file_path /etc/nginx/sites-enabled/espocrm.conf
sudo rm /etc/nginx/sites-enabled/default

sudo cp set-permissions.sh /var/www/espocrm/set-permissions.sh
cd /var/www/espocrm && sudo find data -type d -exec sudo chmod 775 {} + && sudo chown -R 33:33 .;


echo "DB user: espocrmuser"
echo "DB user password: $DB_USER_PASS"
