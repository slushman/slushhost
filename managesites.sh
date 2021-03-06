#!/bin/bash

# Updates an existing WordPress config file with FTP via SSH info
#
# Usage:
# wp_update_config $wp_dir_path
#
# Requires parameters:
# 	$1: The path to the WP site
function add_ssh_updating()
{
	# Path to the wp-config.php file for this domain
	wp_config_file=$1/wp-config.php

	cd

	if [ ! -f wp_rsa ]; then

		sudo ssh-keygen -f wp_rsa -N ''
		sudo chown $USER:nginx wp_rsa
		sudo chown $USER:nginx wp_rsa.pub
		sudo chmod 0700 wp_rsa
		sudo chmod 0700 wp_rsa.pub
		sudo sed -i 's|^|from="127.0.0.1" |' wp_rsa.pub
		cat /home/$USER/wp_rsa.pub >> /home/$USER/.ssh/authorized_keys

	fi

	sudo chown -R $USER:$USER $wp_config_file

	echo "" >> $wp_config_file
	echo "/* Add SSH key for updating WP, plugins, and themes */" >> $wp_config_file
	echo "define('FTP_PUBKEY', '/home/$USER/wp_rsa.pub');" >> $wp_config_file
	echo "define('FTP_PRIKEY', '/home/$USER/wp_rsa');" >> $wp_config_file
	echo "define('FTP_USER', '$USER');" >> $wp_config_file
	echo "define('FTP_PASS', '');" >> $wp_config_file
	echo "define('FTP_HOST', '127.0.0.1:880');" >> $wp_config_file

	sudo chown -R nginx:nginx $wp_config_file
	sudo chmod 660 $wp_config_file
}

# Escapes special characters for use in the script
#
# Usage:
# 	bashesc $texttobecleaned
# 	
# Requires one parameter:
# 	The text to be cleaned
function bashesc()
{
	printf "%q" "$1";
}

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
	calc_sitename $1
	dbname="${sitename}db"
}

# Creates a new database
# 
# Usage:
# createdb $mysqlpassword $dbname $dbuser
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

# Makes directories for a new site
# 
# Usage:
# make_dirs $wp_dir_path
# 
# Requires one parameter:
# 	The directory you want created
function make_dirs()
{
	sudo mkdir -p $1
}

# Creates the nginx config files
# 
# Usage:
# nginx_configs $sitedomain
# 
# Requires three parameters:
# 	The site domain name
function nginx_configs()
{
	read -p "Is this site's domain a subdomain? (yes or no)" subchoice 
	if [ "$subchoice" = "yes" ]; then
		settingfile=subdomain
	else
		settingfile=defaultsite
	fi

	calc_sitename $1

	# Create nginx site configs
	sudo cp /etc/nginx/sites/$settingfile.settings /etc/nginx/sites/$sitename.conf
	sudo sed -i 's|replacewithsitedomain|'$1'|g' /etc/nginx/sites/$sitename.conf
}

# Imports site files and database from remote server
# 
# Usage:
# remote_db_import $mysqlpassword $dbname $olduser $oldip $olddbname
# 
# Requires parameters:
# 	$1: MySQL root password
# 	$2: New database name
# 	$3: Remote server user name
# 	$4: Remote server IP address
# 	$5: Remote database name
# 	
# 	ssh $oldssh@$oldip "mysqldump $olddbname" | mysql -uroot -p$mysqlpassword $dbname
function remote_db_import()
{
	ssh $3@$4 "mysqldump $5 | gzip" | gzip -d | mysql -uroot -p$1 $2
}

# Installs plugins most commonly used by Slushman
# 
# Usage:
# wp_install_basic_plugins
function wp_install_basic_plugins()
{
	wp plugin install akismet
	wp plugin install better-wp-security
	wp plugin install wordpress-seo
	wp plugin install google-analyticator
	wp plugin install jetpack
}

# Removes dummy user, cleans out WP install, creates the real admin user,
# and sets basic settings.
# 
# Usage:
# wp_instant_setup
function wp_instant_setup()
{
	read -p "Please enter the admin username: " adminuser
	read -p "Please enter the admin email: " adminemail
	read -p "Please enter the admin password: " adminpass
	
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
}

# Updates an existing WordPress config file with new information
#
# Usage:
# wp_update_config $wp_dir_path $dbname $dbuser $dbpassword $newprefix
#
# Requires parameters:
# 	$1: The path to the WP site
# 	$2: The new database name
# 	$3: The new database user name
# 	$4: The new database password
# 	$5: The new database prefix
function wp_update_config()
{
	# Path to the wp-config.php file for this domain
	wp_config_file=$1/wp-config.php

	cd $1
	
	sudo rm -rf $wp_config_file
	wp core config --dbname=$2 --dbuser=$3 --dbpass=$4 --dbprefix=$5
 	wp core update-db
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


scriptloop="y"
while [ "$scriptloop" = "y" ]; do
echo -e  ""
echo -e  ""
echo -e  "New Sites:"
echo -e  ""
echo -e  "1 - Setup Site with WordPress"
echo -e  "2 - Setup New Empty Site"
echo -e  "3 - Add New Database"
echo -e  "4 - Import Database"
echo -e  "5 - Export Database"
echo -e  "6 - Move Site and Database from Another Server"
echo -e  "7 - Disable Site"
echo -e  "8 - Remove Site and WordPress"
echo -e  ""
echo -e  "q - Exit manage sites script"
echo -e  ""
echo -e  "Please enter NUMBER of choice (example: 1):"
read choice
case $choice in



1) # Setup Site with WordPress
read -p "Please enter the full domain for the site: " sitedomain
read -p "Please enter the site title: " sitetitle
read -p "Please enter the MySQL password: " mysqlpassword
read -p "Please enter the new database name: " dbname
read -p "Please enter the new database user name: " dbuser
read -p "Please enter the new database password: " dbpassword
read -p "Please enter the new database prefix: " dbprefix

wp_dir_path=/var/www/$sitedomain/public_html

# Create database
createdb $mysqlpassword $dbname $dbuser

# Create nginx site configs
nginx_configs $sitedomain

# Create site directories
make_dirs $wp_dir_path

sudo chown -R slushman:slushman /var/www/*

cd $wp_dir_path

# Download, configure, and install WordPress
wp core download
wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpassword --dbprefix=$dbprefix

wp core install --url=$sitedomain --title=${sitetitle} --admin_user=dummyadmin --admin_password=dummyadminpassword --admin_email=dummy@example.com

if $(wp core is-installed); then
    echo "WordPress is installed!"
fi

wp_instant_setup

wp_install_basic_plugins

add_ssh_updating $wp_dir_path

sudo rm -rf $wp_dir_path/wp-config-sample.php

# Set permissions and restart nginx
wrapup_nginx
;;



2) # Setup New Empty Site
read -p "Please enter your domain: " sitedomain

nginx_configs $sitedomain

wp_dir_path=/var/www/$sitedomain/public_html

make_dirs $wp_dir_path

wrapup_nginx

# Add SSH key and wp-config.php lines for keeping WP updated
wp_update_config $sitedomain
;;



3) # Add New Database
read -p "Please enter the MySQL password: " mysqlpassword
read -p "Please enter your database username: " dbuser
read -p "Please enter the name of the new database: " dbname

createdb $mysqlpassword $dbname $dbuser
;;



4) # Import Database
read -p "Please enter the full domain for the site: " sitedomain
read -p "Please enter the MySQL password: " mysqlpassword
read -p "Please enter the new database user name: " dbuser
read -p "Please enter the new database user password: " dbpassword

# Calculate database name
calc_dbname $sitedomain

read -p "Is this database for WordPress?" wpdb 
if [ "$wpdb" = "yes" ]; then
	read -p "Please enter the new database prefix: " newprefix

	wp_update_config /var/www/$sitedomain/public_html $dbname $dbuser $dbpassword $newprefix
fi

# Drop database
mysqladmin -uroot -p$mysqlpassword drop $dbname

# Recreate database, grant privileges, then import the sql file
createdb $mysqlpassword $dbname $dbuser

read -p "Is this database located on another server?" remotedb 
if [ "$remotedb" = "yes" ]; then
	read -p "Please enter the SSH username for the old server: " oldssh
	read -p "Please enter the IP address of the old server: " oldip
	read -p "Please enter the old database name: " olddbname

	remote_db_import $mysqlpassword $dbname $oldssh $oldip $olddbname
else
	read -p "Please enter the directory and database file to import: " dbfile

	mysql -uroot -p$mysqlpassword $dbname < $dbfile
fi
;;



5) # Export Database
read -p "Please enter the full domain for the site database you would like to export: " sitedomain

cd /var/www/$sitedomain/public_html

calc_dbname $sitedomain

wp db export $dbname
;;



6) # Import site and database from another server
read -p "Please enter the full domain for the site: " sitedomain
read -p "Please enter the SSH username for the old server: " oldssh
read -p "Please enter the IP address of the old server: " oldip
read -p "Please enter the path (from root) of the site: " oldpath

wp_dir_path=/var/www/$sitedomain/public_html

nginx_configs $sitedomain

make_dirs $wp_dir_path

sudo rsync -av -e ssh --progress $oldssh@$oldip:$oldpath $wp_dir_path
sudo find $wp_dir_path -type d -exec chmod 755 {} \;
sudo find $wp_dir_path -type f -exec chmod 644 {} \;

wrapup_nginx

read -p "Please enter the old database name: " olddbname
read -p "Please enter the new database name: " dbname
read -p "Please enter the MySQL password: " mysqlpassword
read -p "Please enter the current database username: " dbuser
read -p "Please enter the current database user password: " dbpassword
read -p "Please enter the new database prefix: " newprefix

createdb $mysqlpassword $dbname $dbuser

remote_db_import $mysqlpassword $dbname $oldssh $oldip $olddbname

wp_update_config $wp_dir_path $dbname $dbuser $dbpassword $newprefix

add_ssh_updating $wp_dir_path
;;



7) # Disable site
read -p "Please enter the full domain for the site to disable: " sitedomain

# Calculate database name
calc_sitename $sitedomain

# Rename the nginx conf file for this site
sudo cp /etc/nginx/sites/$sitename.conf /etc/nginx/sites/$sitename.settings

# Reload nginx
sudo service nginx reload
;;



8) # Remove Site and WordPress
read -p "Please enter the full domain for the site database you would like to remove: " sitedomain
read -p "Please enter the MySQL password: " mysqlpassword

calc_sitename $sitedomain
calc_dbname $sitedomain

# Drop database
mysqladmin -uroot -p$mysqlpassword drop $dbname
mysqladmin -uroot -p$mysqlpassword reload

# Remove nginx site configs
sudo rm -rf /etc/nginx/sites/$sitename.conf

# Delete site directories
sudo rm -rf /var/www/$sitedomain
sudo service nginx reload
;;



9) # Convert to multisite
read -p "Please enter the full domain for the site to convert: " sitedomain

wp_dir_path=/var/www/$sitedomain/public_html

cd $wp_dir_path

wp core multisite-convert
;;



10) # Install additional plugins
read -p "Please enter the full domain for the site you'd like to install plugins on: " sitedomain

wp_dir_path=/var/www/$sitedomain/public_html

cd $wp_dir_path

wp plugin install code-prettify
wp plugin install nginx-helper
wp plugin install wp-ffpc
wp plugin install easy-wp-smtp
wp plugin install sweetcaptcha-revolutionary-free-captcha-service
wp plugin install wordpress-importer
wp plugin install wordpress-backup-to-dropbox
wp plugin install wp-portfolio
wp plugin install wp-cycle
;;



q)
scriptloop="n"
;;

*)
echo - "Unknown choice! Exiting..."
;;

esac
done