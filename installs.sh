#!/bin/bash
scriptloop="y"
while [ "$scriptloop" = "y" ]; do
echo -e  ""
echo -e  ""
echo -e  "Slushhost Setup:"
echo -e  ""
echo -e  "1 - Download Repos"
echo -e  "2 - Install MariaDB"
echo -e  "3 - Install PHP & PHP-FPM"
echo -e  "4 - Install nginx & PageSpeed"
echo -e  "5 - Install and Config iptables and Fail2Ban"
echo -e  "6 - WP-CLI"
echo -e  "7 - htop and memcache"
echo -e  "8 - Config, Harden, and Start Server"
echo -e  ""
echo -e  "q - Exit Installers"
echo -e  ""
echo -e  "Please enter NUMBER of choice (example: 3):"
read choice
case $choice in

1)
sudo rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
sudo rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
sudo yum -y update
;;



2)
sudo mv ~/slushhost/MariaDB.repo /etc/yum.repos.d/MariaDB.repo
sudo yum -y install MariaDB-server MariaDB-client MariaDB-compat MariaDB-devel MariaDB-shared MariaDB-test

sudo service mysql start

read -p "Please enter the new MySQL root password: " mysqlpassword
read -p "Please enter your database username: " dbuser
read -p "Please enter your database password: " dbpassword

sudo mysql_upgrade --force --verbose
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -e "DROP DATABASE test;"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
sudo mysqladmin -u root password $mysqlpassword
sudo mysql -uroot -p$mysqlpassword -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpassword'"
sudo mysql -uroot -p$mysqlpassword -e "FLUSH PRIVILEGES;"
sudo service mysql restart
;;



3)
sudo yum -y --enablerepo=remi,remi-php55 install php-fpm php-mysql php-gd php-common php-pear php-mbstring php-mcrypt php-xml php-pecl-apc php-devel php-mysqlnd
;;



4)
cd
sudo yum -y install gcc gcc-c++ pcre-dev pcre-devel zlib-devel make openssl-devel
wget https://github.com/pagespeed/ngx_pagespeed/archive/v1.7.30.1-beta.zip
sudo mv v1.7.30.1-beta v1.7.30.1-beta.zip
unzip v1.7.30.1-beta.zip
cd ngx_pagespeed-1.7.30.1-beta/
wget https://dl.google.com/dl/page-speed/psol/1.7.30.1.tar.gz
tar -xzvf 1.7.30.1.tar.gz
cd
wget http://nginx.org/download/nginx-1.5.6.tar.gz
tar -xvzf nginx-1.5.6.tar.gz
cd ~/nginx-1.5.6

./configure \
--user=nginx                          \
--group=nginx                         \
--prefix=/etc/nginx                   \
--sbin-path=/usr/sbin/nginx           \
--conf-path=/etc/nginx/nginx.conf     \
--pid-path=/var/run/nginx.pid         \
--lock-path=/var/run/nginx.lock       \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--with-http_gzip_static_module        \
--with-http_stub_status_module        \
--with-http_ssl_module                \
--with-pcre                           \
--with-file-aio                       \
--with-http_realip_module             \
--without-http_scgi_module            \
--without-http_uwsgi_module           \
--add-module=$HOME/ngx_pagespeed-1.7.30.1-beta \
--with-http_spdy_module

sudo make install
cd ~/ngx_pagespeed-1.7.30.1-beta/
scripts/pagespeed_libraries_generator.sh > ~/pagespeed_libraries.conf
sudo mv ~/slushhost/nginx.sh /etc/init.d/nginx
sudo chmod +x /etc/init.d/nginx
sudo chkconfig nginx on
sudo useradd -r nginx
;;



5)
sudo iptables -F 
sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
sudo iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT 
sudo iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT 
sudo iptables -A INPUT -p tcp -m tcp --dport 880 -j ACCEPT 
sudo iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD DROP
sudo iptables -P INPUT DROP
sudo iptables-save | sudo tee /etc/sysconfig/iptables
sudo service iptables restart
sudo yum -y install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i 's/port=ssh/port=880/g' /etc/fail2ban/jail.local 
sudo service fail2ban start
;;



6)
source ~/.bash_profile
cd
git clone git://github.com/wp-cli/wp-cli.git
cd wp-cli
curl -s https://getcomposer.org/installer | php -d memory_limit=512M -d allow_url_fopen=1 -d suhosin.executor.include.whitelist=phar
php composer.phar install --dev
php composer.phar require --prefer-source wp-cli/wp-cli=@stable
php composer.phar --quiet require --prefer-source 'd11wtq/boris=@stable'
sudo ln -s ~/wp-cli/bin/wp /usr/local/bin/
;;



7) # htop and memcache
sudo yum -y install htop
sudo yum -y --enablerepo=remi,remi-php55 install memcached php-pecl-memcached.x86_64
sudo sed -i 's/OPTIONS=""/OPTIONS="-l 127.0.0.1"/g' /etc/sysconfig/memcached
sudo service php-fpm restart
;;



8) # Config, Harden, and Start Server
sudo mkdir -p /var/www/
sudo chmod 755 /var/www
sudo mkdir -p /var/ngx_pagespeed_cache/
sudo chown -R nginx:nginx /var/ngx_pagespeed_cache
sudo usermod -a -G nginx slushman

sudo mv /etc/nginx/nginx.conf /etc/nginx/old.nginx.settings
sudo mv /etc/nginx/mime.types /etc/nginx/old.mime.types.settings
sudo cp /etc/php.ini /etc/old.php.settings
sudo cp /etc/php-fpm.d/www.conf  /etc/php-fpm.d/old.www.settings

cd ~/slushhost/nginx/
sudo mv -f * /etc/nginx
sudo mv ~/pagespeed_libraries.conf /etc/nginx/configs/
sudo mv -f ~/slushhost/www.conf /etc/php-fpm.d/www.conf
sudo mv -f ~/slushhost/php-fpm.conf /etc/php-fpm.conf
sudo mv -f ~/slushhost/php.ini /etc/php.ini
sudo mv -f ~/slushhost/sysctl.conf /etc/sysctl.conf

sudo dd if=/dev/zero of=/swapfile bs=1024 count=512k
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile          swap            swap    defaults        0 0" >> /etc/fstab
chown root:root /swapfile 
chmod 0600 /swapfile

sudo service php-fpm start 
sudo service nginx start
sudo service mysql restart
sudo service memcached start
sudo chkconfig --levels 235 mysql on
sudo chkconfig --levels 235 nginx on
sudo chkconfig --levels 235 php-fpm on
sudo chkconfig --levels 235 memcached on
sudo chkconfig --levels 235 fail2ban on
;;



q)
scriptloop="n"
;;

*)
echo - "Unknown choice! Exiting..."
;;

esac
done 