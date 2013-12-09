#!/bin/bash

# Calculates the sitename from the site domain
# 
# Usage:
# calc_sitename $sitedomain
# 
# Requires one parameter:
# 	The site domain name
function calc_sitename()
{
	sitename=${1:0:${#1}-4}
}

# Calculates the database name from the site name
# 
# Usage:
# calc_dbname $sitename
# 
# Requires two parameters:
# 	The site name
function calc_dbname()
{
        dbname="${1}db"
}

# Creates a new database
# 
# Usage:
# createdb $rootpassword $dbname $dbuser
# 
# Requires three parameters:
# 	The MySQL root password
# 	The database name
# 	The database user name
function createdb()
{
	# Create database
	mysqladmin -uroot -p$1 create $2
	mysql -uroot -p$1 -e "GRANT ALL ON $2.* TO '$3'@'localhost';"
	mysqladmin -uroot -p$1 reload

	test -d "/var/lib/mysql/$2" && echo "Database created successfully" || echo "Database was not created"
}

# Makes directories for a new site and adds link for phpMyAdmin
# phpMyAdmin link is commented out for now until it works
# 
# Usage:
# make_dirs $sitedomain
# 
# Requires one parameter:
# 	The site domain
function make_dirs()
{
	sudo mkdir -p /var/www/$1/public_html
	#sudo ln -s /usr/share/phpMyAdmin/ /var/www/$1/public_html
}

# Creates the nginx config files
# 
# Usage:
# nginx_configs $settingfile $sitedomain $sitename
# 
# Requires three parameters:
# 	The settings file name
# 	The site domain name
# 	The site name
function nginx_configs()
{
	# Create nginx site configs
	sudo cp /etc/nginx/sites/$1.settings /etc/nginx/sites/$3.conf
	sudo sed -i 's/replacewithsitedomain/'$2'/g' /etc/nginx/sites/$3.conf
}

# Sets permissions on the nginx site and log directories and reloads nginx config
# 
# Usage:
# wrapup_nginx
function wrapup_nginx()
{
	sudo chown -R nginx:nginx /var/www/*
	sudo chown -R nginx:nginx /var/log/*
	sudo service nginx reload
}

# Creates a new SSH key for WordPress updates and adds lines to wp-config.php
# so WP can updates itself, plugins, and themes without asking for FTP creds.
# 
# Usage:
# wp_update_config $sitedomain
# 
# Requires one parameter:
# 	The site domain
function wp_update_config()
{
	cd
	sudo ssh-keygen -f wp_rsa -N ''
	sudo chown $USER:nginx wp_rsa
	sudo chown $USER:nginx wp_rsa.pub
	sudo chmod 0700 wp_rsa
	sudo chmod 0700 wp_rsa.pub
	sudo sed -i '1s/^/from="127.0.0.1" /' wp_rsa.pub
	cat /home/$USER/wp_rsa.pub >> /home/$USER/.ssh/authorized_keys

	# Path to the wp-config.php file for this domain
	wp_config_path=/var/www/$1/public_html/wp-config.php

	echo "define('FTP_PUBKEY', '/home/'$USER'/wp_rsa.pub');" >> $wp_config_path
	echo "define('FTP_PRIKEY', '/home/'$USER'/wp_rsa');" >> $wp_config_path
	echo "define('FTP_USER', '$USER');" >> $wp_config_path
	echo "define('FTP_PASS', '');" >> $wp_config_path
	echo "define('FTP_HOST', '127.0.0.1:25000');" >> $wp_config_path
}

# Imports site files and database from remote server
# 
# Usage:
# remote_db_import $rootpassword $dbname $dbuser $olduser $oldip $olddbuser $olddbroot $olddbname
# 
# Requires parameters:
# 	$1: MySQL root password
# 	$2: New database name
# 	$3: New database username
# 	$4: Remote server user name
# 	$5: Remote server IP address
# 	$6: Remote MySQL root password
# 	$7: Remote MySQL user name
# 	$8: Remote database name
function remote_db_import()
{
	# createdb $rootpassword $dbname $dbuser
	createdb $1 $2 $3

	# ssh $olduser@$oldip "mysqldump -uroot -p$olddbroot $olddbname" | mysql -uroot -p$rootpassword $dbname
	ssh $4@$5 "mysqldump -u$7 -p$6 $8 | gzip" | gzip -d | mysql -uroot -p$1 $2

}



scriptloop="y"
while [ "$scriptloop" = "y" ]; do
echo -e  ""
echo -e  ""
echo -e  "New Sites:"
echo -e  ""
echo -e  "1 - Setup Site with WordPress"
echo -e  "2 - Setup New Empty Site"
echo -e  "3 - Add New Database"
echo -e  "4 - Import WordPress Database"
echo -e  "5 - Export Database"
echo -e  "6 - Move Site from Another Server"
echo -e  "7 - Remove Site and WordPress"
echo -e  ""
echo -e  "q - Exit new site script"
echo -e  ""
echo -e  "Please enter NUMBER of choice (example: 1):"
read choice
case $choice in



1) # Setup Site with WordPress
read -p "Please enter your domain (with subdomain, if needed): " sitedomain
read -p "Please enter your site title: " sitetitle
read -p "Please enter the WP database prefix: " dbprefix
read -p "Please enter your admin username: " adminuser
read -p "Please enter your admin email: " adminemail
read -p "Please enter your admin password: " adminpass
read -p "Please enter the MySQL password: " rootpassword
read -p "Please enter your database username: " dbuser
read -p "Please enter the name of the new database: " dbname

wp_dir_path=/var/www/$sitedomain/public_html

calc_sitename $sitedomain

read -p "Is this site's domain a subdomain? (yes or no)" subchoice 
if [ "$subchoice" = "yes" ]; then
	settingfile=subdomain
else
	settingfile=defaultsite
fi

# Create database
createdb $rootpassword $dbname $dbuser

# Create nginx site configs
nginx_configs $settingfile $sitedomain $sitename

# Create site directories
make_dirs $wp_dir_path

sudo chown -R slushman:slushman /var/www/*
cd $wp_dir_path

# Download, configure, and install WordPress
wp core download
wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpassword --dbprefix=$dbprefix

wp core install --url=$sitedomain --title=$sitetitle --admin_user=dummyadmin --admin_password=dummyadminpassword --admin_email=dummy@example.com

if $(wp core is-installed); then
    echo "WordPress is installed!"
fi

wp user delete 1
wp site empty --yes
wp plugin delete hello
wp user create $adminuser $adminemail --user_pass=$adminpass
wp user add-role $adminuser administrator
wp option update cadmin_email $adminemail
wp option update cavatar_rating 'G'
wp option delete cblogdescription
wp option update cclose_comments_days_old '30'
wp option update cclose_comments_for_old_posts '1'
wp option update ccomment_registration '1'
wp option update cdefault_comments_page 'newest'
wp option update cdefault_pingback_flag '1'
wp option delete cmailserver_login
wp option delete cmailserver_pass
wp option delete cmailserver_url
wp option update cpermalink_structure '/%category%/%postname%/'
wp option update cstart_of_week '0'
wp option update ctimezone_string 'America/Chicago'
wp option update cusers_can_register '1'
wp plugin install better-wp-security --activate
wp plugin install wordpress-seo --activate
wp plugin install google-analyticator --activate
wp plugin install jetpack --activate

sudo rm -rf $wp_dir_path/wp-config-sample.php

# Set permissions and restart nginx
wrapup_nginx
;;



2) # Setup New Empty Site
read -p "Please enter your domain: " sitedomain

calc_sitename $sitedomain

nginx_configs defaultsite $sitedomain $sitename

make_dirs $sitedomain

wrapup_nginx

# Add SSH key and wp-config.php lines for keeping WP updated
wp_update_config $sitedomain
;;



3) # Add New Database
read -p "Please enter the MySQL password: " rootpassword
read -p "Please enter your database username: " dbuser
read -p "Please enter the name of the new database: " dbname

createdb $rootpassword $dbname $dbuser
;;



4) # Import WordPress Database
read -p "Please enter the domain (with subdomain, if needed) for the database you'd like to import: " sitedomain
read -p "Please enter the MySQL password: " rootpassword
read -p "Please enter your database username: " dbuser
read -p "Please enter the name of the new database: " dbname
read -p "Please enter your database password: " dbpassword
read -p "Please enter directory and database file to import (include the .sql extension): " dbfile

wp_dir_path=/var/www/$sitedomain/public_html

calc_sitename $sitedomain
calc_dbname $sitename

# Drop database
mysqladmin -uroot -p$rootpassword drop $dbname

# Recreate database, grant privileges, then import the sql file
createdb $rootpassword $dbname $dbuser

mysql -uroot -p$rootpassword $dbname < $dbfile

cd $wp_dir_path

wp core update-db

read -p "Please enter the imported database prefix: " newprefix

wpdbname=`cat wp-config.php | grep DB_NAME | cut -d \' -f 4`
wpdbuser=`cat wp-config.php | grep DB_USER | cut -d \' -f 4`
wpdbpass=`cat wp-config.php | grep DB_PASSWORD | cut -d \' -f 4`
currprefix=`sudo cat wp-config.php | grep table_prefix | cut -d \' -f 2`

# Path to the wp-config.php file for this domain
wp_config_path=$wp_dir_path/wp-config.php

sudo sed -i 's/'$wpdbname'/'$dbname'/g' $wp_dir_path
sudo sed -i 's/'$wpdbuser'/'$dbuser'/g' $wp_dir_path
sudo sed -i 's/'$wpdbpass'/'$dbpassword'/g' $wp_dir_path
sudo sed -i 's/'$currprefix'/'$newprefix'/g' $wp_dir_path

# Add SSH key and wp-config.php lines for keeping WP updated
wp_update_config $sitedomain
;;



5) # Export Database
read -p "Please enter the domain (with subdomain, if needed) for the database you'd like to export: " sitedomain

cd /var/www/$sitedomain/public_html

calc_sitename $sitedomain
calc_dbname $sitename

wp db export $dbname
;;



6) # Import site from another server
read -p "Please enter the SSH username for the old server: " olduser
read -p "Please enter the IP address of the old server: " oldip
read -p "Please enter the path (from root) of the site: " oldpath
read -p "Please enter the domain for the site: " sitedomain

calc_sitename $sitedomain

read -p "Is this site's domain a subdomain? (yes or no)" subchoice 
if [ "$subchoice" = "yes" ]; then
	settingfile=subdomain
else
	settingfile=defaultsite
fi

nginx_configs $settingfile $sitedomain $sitename

wp_dir_path=/var/www/$sitedomain/public_html

sudo rsync -av -e ssh --progress $olduser@$oldip:$oldpath $wp_dir_path
sudo find $wp_dir_path -type d -exec chmod 755 {} \;
sudo find $wp_dir_path -type f -exec chmod 644 {} \;

wrapup_nginx

read -p "Please enter the current MySQL password: " rootpassword
read -p "Please enter your current database username: " dbuser
read -p "Please enter the name of the new database: " dbname
read -p "Please enter the MySQL root username for the old server: " olddbuser
read -p "Please enter the MySQL root password for the old server: " olddbroot
read -p "Please enter the old database name: " olddbname

remote_db_import $rootpassword $dbname $dbuser $olduser $oldip $olddbuser $olddbroot $olddbname

cd $wp_dir_path
sudo ls -l
;;



7) # Remove Site and WordPress
read -p "Please enter the domain (with subdomain, if needed) for the database you'd like to remove: " sitedomain
read -p "Please enter the MySQL password: " rootpassword

calc_sitename $sitedomain
calc_dbname $sitename

# Drop database
mysqladmin -uroot -p$rootpassword drop $dbname
mysqladmin -uroot -p$rootpassword reload

# Remove nginx site configs
sudo rm -rf /etc/nginx/sites/$sitename.conf

# Delete site directories
sudo rm -rf /var/www/$sitedomain
sudo service nginx reload
;;



q)
scriptloop="n"
;;

*)
echo - "Unknown choice! Exiting..."
;;

esac
done