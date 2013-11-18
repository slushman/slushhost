#!/bin/bash
scriptloop="y"
while [ "$scriptloop" = "y" ]; do
echo -e  "SELinux Setup:"
echo -e  ""
echo -e  "1 - Download Repos"
echo -e  "2 - Install MariaDB"
echo -e  "3 - Install PHP & PHP-FPM"
echo -e  "4 - Install nginx & PageSpeed"
echo -e  "5 - Setup Directories"
echo -e  "6 - Config iptables"
echo -e  "7 - Install and Config Fail2Ban"
echo -e  "8 - Download WordPress"
echo -e  "9 - memcache"
echo -e  "10 - Config Server"
echo -e  "11 - Start server"
echo -e  "12 - Harden Server"
echo -e  ""
echo -e  "q - EXIT MYSQL SCRIPT!"
echo -e  ""
echo -e  "Please enter NUMBER of choice (example: 3):"
read choice
case $choice in

1)
sudo rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
sudo rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
sudo yum update
;;

2)
sudo yum -y install MariaDB-server MariaDB-client MariaDB-compat MariaDB-devel MariaDB-shared MariaDB-test
sudo service mysql start
sudo /usr/bin/mysql_secure_installation
;;

3)
sudo yum --enablerepo=remi install php-fpm php-mysql php-gd
sudo yum --enablerepo=remi install php-pear php-mbstring php-mcrypt php-xml
sudo yum --enablerepo=remi install php-pecl-apc php-devel
;;

4)
cd
sudo yum install gcc-c++ pcre-dev pcre-devel zlib-devel make
wget https://github.com/pagespeed/ngx_pagespeed/archive/v1.7.30.1-beta.zip
unzip v1.7.30.1-beta.zip
wget http://nginx.org/download/nginx-1.4.3.tar.gz 
tar -xvzf nginx-1.4.3.tar.gz
cd ngx_pagespeed-1.7.30.1-beta/
wget https://dl.google.com/dl/page-speed/psol/1.7.30.1.tar.gz 
tar -xzvf 1.7.30.1.tar.gz
cd ~/nginx-1.4.3
./configure --add-module=/home/slushman/ngx_pagespeed-release-1.7.30.1-beta
make
sudo make install
scripts/pagespeed_libraries_generator.sh > ~/pagespeed_libraries.conf
sudo mv ~/pagespeed_libraries.conf /etc/nginx/configs/

5)
sudo mkdir -p /var/www/
sudo chmod 755 /var/www
sudo mkdir -p /var/ngx_pagespeed_cache/
sudo chown -R nginx:nginx /var/ngx_pagespeed_cache
sudo usermod -a -G nginx slushman
;;

6)
sudo iptables -F 
sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
sudo iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT 
sudo iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT 
sudo iptables -A INPUT -p tcp -m tcp --dport 25000 -j ACCEPT 
sudo iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD DROP
sudo iptables -P INPUT DROP
sudo iptables-save | sudo tee /etc/sysconfig/iptables
sudo service iptables restart
;;

7)
sudo yum install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i 's/[name=SSH, port=ssh, protocol=tcp]/[name=SSH, port=25000, protocol=tcp]/g' /etc/fail2ban/jail.local 
sudo service fail2ban start
;;

8)
cd
curl https://raw.github.com/wp-cli/wp-cli.github.com/master/installer.sh | bash
sudo sed -i 's/export PATH/export PATH=/root/.wp-cli/bin:$PATH/g' ~/.bash_profile
echo "source $HOME/.wp-cli/vendor/wp-cli/wp-cli/utils/wp-completion.bash" >> ~/.bash_profile
source ~/.bash_profile
;;

9)
sudo yum --enablerepo=remi install memcached
sudo sed -i 's/OPTIONS=""/OPTIONS="-l 127.0.0.1"/g' /etc/sysconfig/memcached
;;

10)
sudo mkdir -p /etc/nginx/configs
sudo mkdir -p /etc/nginx/sites
sudo mkdir -p /etc/nginx/sites/configs
sudo mv /etc/nginx/nginx.conf /etc/nginx/old.nginx.conf
sudo mv /etc/nginx/mime.types /etc/nginx/old.mime.types
sudo cp /etc/php.ini /etc/old.php.ini
sudo cp /etc/php-fpm.d/www.conf  /etc/php-fpm.d/old.www.conf
sudo mkdir /etc/nginx/configs/.htpasswd/
sudo htpasswd -c /etc/nginx/configs/.htpasswd/passwd slushman
sudo mv /slushhost/nginx/sites/* /etc/nginx/sites/*
sudo mv /slushhost/nginx/configs/* /etc/nginx/configs/*
sudo mv /slushhost/nginx/nginx.conf /etc/nginx
sudo mv /slushhost/nginx/mime.types /etc/nginx
sudo sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 15M/g' /etc/php.ini
sudo sed -i 's/allow_url_fopen = On/allow_url_fopen = Off/g' /etc/php.ini
sudo sed -i 's/post_max_size = 8M/post_max_size = 15M/g' /etc/php.ini
sudo sed -i 's/;default_charset = "UTF-8"/default_charset = "UTF-8"/g' /etc/php.ini
sudo sed -i 's/default_socket_timeout = 60/default_socket_timeout = 30/g' /etc/php.ini
sudo sed -i 's/mysql.allow_persistent = On/mysql.allow_persistent = Off/g' /etc/php.ini
sudo sed -i 's/expose_php = On/expose_php = Off/g' /etc/php.ini
sudo sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sudo sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf
sudo sed -i 's/;emergency_restart_threshold = 0/emergency_restart_threshold = 5/g' /etc/php-fpm.conf
sudo sed -i 's/;emergency_restart_interval = 0/emergency_restart_interval = 2/g' /etc/php-fpm.conf
echo "events.mechanism = epoll" >> /etc/php-fpm.conf
echo "[apc]" >> /etc/php.ini
echo "apc.stat = 0" >> /etc/php.ini
echo "apc.max_file_size = 2M" >> /etc/php.ini
echo "apc.localcache = 1" >> /etc/php.ini
echo "apc.localcache.size = 256" >> /etc/php.ini
echo "apc.shm_segments = 1" >> /etc/php.ini
echo "apc.ttl = 3600" >> /etc/php.ini
echo "apc.user_ttl = 7200" >> /etc/php.ini
echo "apc.gc_ttl = 3600" >> /etc/php.ini
echo "apc.cache_by_default = 1" >> /etc/php.ini
echo "apc.filters = " >> /etc/php.ini
echo "apc.write_lock = 1" >> /etc/php.ini
echo "apc.num_files_hint= 512" >> /etc/php.ini
echo "apc.user_entries_hint=4096" >> /etc/php.ini
echo "apc.shm_size = 256M" >> /etc/php.ini
echo "apc.mmap_file_mask=/tmp/apc.XXXXXX" >> /etc/php.ini
echo "apc.include_once_override = 0" >> /etc/php.ini
echo "apc.file_update_protection=2" >> /etc/php.ini
echo "apc.canonicalize = 1" >> /etc/php.ini
echo "apc.report_autofilter=0" >> /etc/php.ini
echo "apc.stat_ctime=0" >> /etc/php.ini
echo ";This should be used when you are finished with PHP file changes." >> /etc/php.ini
echo ";As you must clear the APC cache to recompile already cached files." >> /etc/php.ini
echo ";If you are still developing, set this to 1." >> /etc/php.ini
echo "apc.stat=0" >> /etc/php.ini
;;

11)
sudo service php-fpm start 
sudo service nginx start
sudo service mysqld restart
sudo service memcached start
sudo chkconfig --levels 235 mysqld on
sudo chkconfig --levels 235 nginx on
sudo chkconfig --levels 235 php-fpm on
sudo chkconfig --levels 235 memcached on
sudo chkconfig --levels 235 fail2ban
;;

12)
echo "# Avoid a smurf attack" >> /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Turn on protection for bad icmp error messages" >> /etc/sysctl.conf
echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Turn on and log spoofed, source routed, and redirect packets" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.log_martians = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.log_martians = 1" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# No source routed packets here" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_source_route = 0" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Turn on reverse path filtering" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter = 1" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Make sure no one can alter the routing tables" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.secure_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.secure_redirects = 0" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Don't act as a router" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Turn on execshild" >> /etc/sysctl.conf
echo "kernel.exec-shield = 1" >> /etc/sysctl.conf
echo "kernel.randomize_va_space = 1" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Tune IPv6" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.router_solicitations = 0" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.accept_ra_rtr_pref = 0" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.accept_ra_pinfo = 0" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.accept_ra_defrtr = 0" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.autoconf = 0" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.dad_transmits = 0" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.max_addresses = 1" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Optimization for port usefor LBs" >> /etc/sysctl.conf
echo "# Increase system file descriptor limit" >> /etc/sysctl.conf
echo "fs.file-max = 65535" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Allow for more PIDs (to reduce rollover problems); may break some programs 32768" >> /etc/sysctl.conf
echo "kernel.pid_max = 65536" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Increase system IP port limits" >> /etc/sysctl.conf
echo "net.ipv4.ip_local_port_range = 2000 65000" >> /etc/sysctl.conf
echo "" >> /etc/sysctl.conf
echo "# Increase Linux auto tuning TCP buffer limits" >> /etc/sysctl.conf
echo "# min, default, and max number of bytes to use" >> /etc/sysctl.conf
echo "# set max to at least 4MB, or higher if you use very high BDP paths" >> /etc/sysctl.conf
echo "# Tcp Windows etc" >> /etc/sysctl.conf
echo "net.core.netdev_max_backlog = 5000" >> /etc/sysctl.conf
echo "net.ipv4.tcp_window_scaling = 1" >> /etc/sysctl.conf
;;

q)
scriptloop="n"
;;

*)
echo - "Unknown choice! Exiting..."
;;

esac
done 