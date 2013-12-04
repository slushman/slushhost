#!/bin/bash
scriptloop="y"
while [ "$scriptloop" = "y" ]; do
echo -e  ""
echo -e  ""
echo -e  "New Sites:"
echo -e  ""
echo -e  "1 - Setup New Site"
echo -e  "2 - Setup Site with WordPress"
echo -e  "3 - Import Database"
echo -e  "4 - Remove Site and WordPress"
echo -e  ""
echo -e  "q - Exit new site script"
echo -e  ""
echo -e  "Please enter NUMBER of choice (example: 1):"
read choice
case $choice in



1)
echo -e "Please enter your domain: "
read sitedomain

sitename=${sitedomain:0:-4}

sudo cp /etc/nginx/sites/defaultsite.settings /etc/nginx/sites/$sitename.conf
sudo sed -i 's/replacewithsitedomain/'$sitedomain'/g' /etc/nginx/sites/$sitename.conf

sudo mkdir -p /var/www/$sitedomain/public_html
sudo ln -s /usr/share/phpMyAdmin/ /var/www/$sitedomain/public_html
sudo chown -R slushman:slushman /var/www/*
cd /var/www/$sitedomain/public_html

sudo chown -R nginx:nginx /var/www/*
sudo chown -R nginx:nginx /var/log/*
sudo service nginx restart
;;



2)
echo -e "Please enter your domain (with subdomain, if needed): "
read sitedomain

echo -e "Please enter your site title: "
read sitetitle

echo -e "Please enter the WP database prefix: "
read dbprefix

if test -r "~/slushhost.cfg" -a -f "~/slushhost.cfg"
	then
	source ~/slushhost.cfg
else 
	echo -e "Please enter your admin username: "
	read adminuser

	echo -e "Please enter your admin email: "
	read adminemail

	echo -e "Please enter your admin password: "
	read adminpass

	echo -e "Please enter the MySQL password: "
	read rootpassword

	echo -e "Please enter your database username: "
	read dbuser

	echo -e "Please enter your database password: "
	read dbpassword
fi

sitename=${sitedomain:0:${#sitedomain}-4}

read -p "Is this site's domain a subdomain? (yes or no)" subchoice 
if [ "$subchoice" = "yes" ]; then
	settingfile=subdomain
	dbname="${sitename/./}db"
else
	settingfile=defaultsite
	dbname="${sitename}db"
fi

# Create database
mysqladmin -uroot -p$rootpassword create $dbname
mysql -uroot -p$rootpassword -e "GRANT ALL ON $dbname.* TO '$dbuser'@'localhost';"
mysqladmin -uroot -p$rootpassword reload

test -d "/var/lib/mysql/$dbname" && echo "Database created successfully" || echo "Database was not created"

# Create nginx site configs
sudo cp /etc/nginx/sites/$settingfile.settings /etc/nginx/sites/$sitename.conf
sudo sed -i 's/replacewithsitedomain/'$sitedomain'/g' /etc/nginx/sites/$sitename.conf

# Create site directories
sudo mkdir -p /var/www/$sitedomain/public_html
sudo ln -s /usr/share/phpmyadmin/ /var/www/$sitedomain/public_html
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
wp site empty
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
sudo chown -R nginx:nginx /var/www/*
sudo chown -R nginx:nginx /var/log/*
sudo service nginx reload
;;



3)
echo -e "Please enter the domain (with subdomain, if needed) for the database you'd like to import: "
read sitedomain

echo -e "Please enter the MySQL password: "
read rootpassword

echo -e "Please enter your database username: "
read dbuser

echo -e "Please enter directory and database file to import (include the .sql extension): "
read dbfile

sitename=${sitedomain:0:${#sitedomain}-4}
dbname="${sitename/./}db"

# Drop database
mysqladmin -uroot -p$rootpassword drop $dbname

# Recreate database, grant privileges, then import the sql file
mysqladmin -uroot -p$rootpassword create $dbname
mysql -uroot -p$rootpassword -e "GRANT ALL ON $dbname.* TO '$dbuser'@'localhost';"
mysqladmin -uroot -p$rootpassword reload
mysql -uroot -p$rootpassword $dbname < $dbfile

cd /var/www/$sitedomain/public_html

wp core update-db

echo -e "Please enter the imported database prefix: "
read newprefix

currprefix=`sudo cat wp-config.php | grep table_prefix | cut -d \' -f 2`

sudo sed -i 's/'$currprefix'/'$newprefix'/g' /var/www/$sitedomain/public_html/wp-config.php

### This bit works well and uses WP-CLI
### but it leaves the old tables in place
#echo -e "Please enter the domain (with subdomain, if needed) for the database you'd like to import: "
#read sitedomain
#
#cd /var/www/$sitedomain/public_html
#
#echo -e "Please enter directory and database file to import (include the .sql extension): "
#read dbfile
#
#wp db import $dbfile.sql
#wp core update-db
#
#echo -e "Please enter the imported database prefix: "
#read newprefix
#
#currprefix=`sudo cat wp-config.php | grep table_prefix | cut -d \' -f 2`
#
#sudo sed -i 's/'$currprefix'/'$newprefix'/g' /var/www/$sitedomain/public_html/wp-config.php
;;



4)
echo -e "Please enter your domain (with subdomain, if needed): "
read sitedomain

echo -e "Please enter the MySQL password: "
read rootpassword

sitename=${sitedomain:0:${#sitedomain}-4}
dbname="${sitename/./}db"

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