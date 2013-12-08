#!/bin/bash

# Requires one parameter:
# 	The site domain name
function calc_sitename()
{
	sitename=${1:0:${#1}-4}
}

# Requires two parameters:
# 	The site name
function calc_dbname()
{
        dbname="${1}db"
}

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
}

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

calc_sitename $sitedomain

read -p "Is this site's domain a subdomain? (yes or no)" subchoice 
if [ "$subchoice" = "yes" ]; then
	settingfile=subdomain
else
	settingfile=defaultsite
fi

# Create database
createdb $rootpassword $dbname $dbuser

test -d "/var/lib/mysql/$dbname" && echo "Database created successfully" || echo "Database was not created"

# Create nginx site configs
nginx_configs $settingfile $sitedomain $sitename

# Create site directories
sudo mkdir -p /var/www/$sitedomain/public_html
#sudo ln -s /usr/share/phpmyadmin/ /var/www/$sitedomain/public_html
sudo chown -R slushman:slushman /var/www/*
cd /var/www/$sitedomain/public_html

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

sudo rm -rf /var/www/$sitedomain/public_html/wp-config-sample.php

# Set permissions and restart nginx
wrapup_nginx
;;



2) # Setup New Empty Site
read -p "Please enter your domain: " sitedomain

calc_sitename $sitedomain

nginx_configs defaultsite $sitedomain $sitename

sudo mkdir -p /var/www/$sitedomain/public_html
#sudo ln -s /usr/share/phpMyAdmin/ /var/www/$sitedomain/public_html
wrapup_nginx
;;



3) # Add New Database
read -p "Please enter the MySQL password: " rootpassword
read -p "Please enter your database username: " dbuser
read -p "Please enter the name of the new database: " dbname

createdb $rootpassword $dbname $dbuser

test -d "/var/lib/mysql/$dbname" && echo "Database created successfully" || echo "Database was not created"
;;


4) # Import Database
read -p "Please enter the domain (with subdomain, if needed) for the database you'd like to import: " sitedomain
read -p "Please enter the MySQL password: " rootpassword
read -p "Please enter your database username: " dbuser
read -p "Please enter the name of the new database: " dbname
read -p "Please enter your database password: " dbpassword
read -p "Please enter directory and database file to import (include the .sql extension): " dbfile

calc_sitename $sitedomain
calc_dbname $sitename

# Drop database
mysqladmin -uroot -p$rootpassword drop $dbname

# Recreate database, grant privileges, then import the sql file
createdb $rootpassword $dbname $dbuser

mysql -uroot -p$rootpassword $dbname < $dbfile

cd /var/www/$sitedomain/public_html

wp core update-db

read -p "Please enter the imported database prefix: " newprefix

wpdbname=`cat wp-config.php | grep DB_NAME | cut -d \' -f 4`
wpdbuser=`cat wp-config.php | grep DB_USER | cut -d \' -f 4`
wpdbpass=`cat wp-config.php | grep DB_PASSWORD | cut -d \' -f 4`
currprefix=`sudo cat wp-config.php | grep table_prefix | cut -d \' -f 2`

sudo sed -i 's/'$wpdbname'/'$dbname'/g' /var/www/$sitedomain/public_html/wp-config.php
sudo sed -i 's/'$wpdbuser'/'$dbuser'/g' /var/www/$sitedomain/public_html/wp-config.php
sudo sed -i 's/'$wpdbpass'/'$dbpassword'/g' /var/www/$sitedomain/public_html/wp-config.php
sudo sed -i 's/'$currprefix'/'$newprefix'/g' /var/www/$sitedomain/public_html/wp-config.php

cd
sudo ssh-keygen -f wp_rsa -N ''
sudo chown $USER:nginx wp_rsa
sudo chown $USER:nginx wp_rsa.pub
sudo chmod 0640 wp_rsa
sudo chmod 0640 wp_rsa.pub
sudo sed -i '1s/^/from="127.0.0.1" /' wp_rsa.pub
cat /home/$USER/wp_rsa.pub >> /home/$USER/.ssh/authorized_keys

echo "define('FTP_PUBKEY', '/home/slushman/wp_rsa.pub');" >> /var/www/$sitedomain/public_html/wp-config.php
echo "define('FTP_PRIKEY', '/home/slushman/wp_rsa');" >> /var/www/$sitedomain/public_html/wp-config.php
echo "define('FTP_USER', 'slushman');" >> /var/www/$sitedomain/public_html/wp-config.php
echo "define('FTP_PASS', '');" >> /var/www/$sitedomain/public_html/wp-config.php
echo "define('FTP_HOST', '127.0.0.1:25000');" >> /var/www/$sitedomain/public_html/wp-config.php
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

sudo rsync -av -e ssh --progress $olduser@$oldip:$oldpath /var/www/$sitedomain/public_html
sudo find /var/www/$sitedomain/public_html -type d -exec chmod 755 {} \;
sudo find /var/www/$sitedomain/public_html -type f -exec chmod 644 {} \;

wrapup_nginx

cd /var/www/$sitedomain/public_html
sudo ls -l
;;



7) # Remove Site and WordPress
read -p "Please enter the domain (with subdomain, if needed) for the database you'd like to import: " sitedomain
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