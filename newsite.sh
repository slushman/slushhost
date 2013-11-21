#!/bin/bash
scriptloop="y"
while [ "$scriptloop" = "y" ]; do
echo -e  ""
echo -e  ""
echo -e  "New Sites:"
echo -e  ""
echo -e  "1 - Create directory"
echo -e  "2 - Create MysQL database"
echo -e  "3 - Setup nginx configs"
echo -e  "4 - Create new WP site"
echo -e  "5 - Import Database"
echo -e  ""
echo -e  "q - Exit new site script"
echo -e  ""
echo -e  "Please enter NUMBER of choice (example: 1):"
read choice
case $choice in

1)
echo -e "Please enter your site domain: "
read sitedomain

sudo mkdir -p /var/www/$sitedomain/public_html
sudo ln -s /usr/share/phpmyadmin/ /var/www/$sitedomain/public_html
;;

2)
echo -e "Please enter your MySQL password: "
read dbpassword

echo -e "Please enter your database name (no punctuation please): "
read dbname

echo -e "Please enter your database username: "
read dbuser

mysql -uroot -p$dbpassword -e "CREATE DATABASE IF NOT EXISTS $dbname;"
mysql -uroot -p$dbpassword -e "GRANT ALL ON $dbname.* TO $dbuser;"
mysql -uroot -p$dbpassword -e "FLUSH PRIVILEGES;"

result=$(mysql -s -N -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='db'")
if [ -z "$result" ];
then 
	echo "Database was not created"
else
	echo "Database created successfully"
fi
;;

3)
echo -e "Please enter your site name (one-word, not the domain): "
read sitename

sudo cp /etc/nginx/sites/defaultsite.settings /etc/nginx/sites/$sitename.conf
sudo sed -i 's/replacewithsitedomain/$sitedomain/g' /etc/nginx/sites/$sitename.conf
;;

4)
echo -e "Please enter your site domain: "
read sitedomain

echo -e "Please enter your site title: "
read sitetitle

echo -e "Please enter your admin username: "
read adminuser

echo -e "Please enter your admin email: "
read adminemail

echo -e "Please enter your admin password: "
read adminpass

echo -e "Please enter the WP database prefix: "
read dbprefix

sudo chown -R slushman:slushman /var/www/*
cd /var/www/$sitedomain/public_html

wp core download

:<<'COMMENTOUT'
wp core config --dbname=$dbname --dbuser=root --dbpass=$dbpassword --dbprefix=$dbprefix
wp core install --url=$sitedomain --title=$sitetitle --admin_user=dummyadmin --admin_password=dummyadminpassword --admin_email=dummy@example.com
if $(wp core is-installed); then
    echo "WordPress is installed!"
fi
wp user delete 1
wp site empty
wp user create $adminuser $adminemail --user-pass=$adminpass --role=administrator
wp option update cadmin_email $adminemail
wp option update cavatar_rating 'G'
wp option update cblogname $sitename
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
COMMENTOUT

sudo chown -R nginx:nginx /var/www/*
sudo service nginx restart
;;

5)
echo -e "Please enter your MySQL password: "
read dbpassword

echo -e "Please enter name of the database to import into: "
read importtodbname

echo -e "Please enter directory and database file to import (exclude the .sql extension): "
read dbfile

echo -e "Please enter name of the database file to import: "
read dbfile

mysql -uroot -p$dbpassword $importtodbname < $dbfile.sql
;;

q)
scriptloop="n"
;;

*)
echo - "Unknown choice! Exiting..."
;;

esac
done