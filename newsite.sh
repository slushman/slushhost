#!/bin/bash
scriptloop="y"
while [ "$scriptloop" = "y" ]; do
echo -e  ""
echo -e  ""
echo -e  "New Sites:"
echo -e  ""
echo -e  "1 - Create new WP site"
echo -e  "2 - Import Database"
echo -e  ""
echo -e  "q - Exit new site script"
echo -e  ""
echo -e  "Please enter NUMBER of choice (example: 1):"
read choice
case $choice in

1)
echo -e "Please enter your site domain: "
read sitedomain

echo -e "Please enter your site name: "
read sitename

sudo mkdir -p /var/www/$sitedomain/public_html
cd /var/www/$sitedomain/public_html

echo -e "Please enter your database name (no punctuation please): "
read dbname

echo -e "Please enter your database username: "
read dbuser

echo -e "Please enter your database password: "
read dbpassword

mysql -uroot -p$dbpassword -e "CREATE DATABASE IF NOT EXISTS $dbname;"
mysql -uroot -p$dbpassword -e "GRANT ALL ON $dbname.* TO $dbuser;"
mysql -uroot -p$dbpassword -e "FLUSH PRIVILEGES;"

sudo chown -R nginx:nginx /var/www/*
sudo cp /etc/nginx/sites/defaultsite.settings /etc/nginx/sites/$sitename.conf
sudo sed -i 's/replacewithsitedomain/$sitedomain/g' /etc/nginx/sites/$sitename.conf

echo -e "Please enter your admin email: "
read adminemail

wp core download
wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpassword
wp core install
wp user delete 1
wp site empty
wp user create $dbuser $adminemail --role=administrator
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

sudo service nginx reload
;;

2)
echo -e "Please enter name of the database to import into: "
read importtodbname

echo -e "Please enter name of the directory where the database file resides: "
read importdbdir

echo -e "Please enter name of the database file to import: "
read dbfile

echo -e "Please enter name of the database to import into: "
read dbpassword

mysql -uroot -p$dbpassword $importtodbname < $importdbdir/$dbfile.sql
;;

q)
scriptloop="n"
;;

*)
echo - "Unknown choice! Exiting..."
;;

esac
done