Slushhost Config Instructions
====================

These instructions are intended for setting up a CentOS 6 64-bit server image from Digital Ocean. They may work for other hosts, but probably not a different Linux OS.

Accounts & Password Document
---------------

Create a plain-text document on your computer with the following items:

* root password
* your user account password
* MySQL root password
* MySQL user name
* MySQL user password

If you're moving from another server:
* Path to the site on the old server
* Old server user name with root permissions
* Old server IP address
* Old server MySQL root password
* Old server database name

I would also advise adding a few lines:

    mysql -u[your root username] -p[your mysql root password]
    ./slushhost/managesites.sh

Just makes life easier than typing it every time. When I refer to pasting something in, its going to be from this text document.

You may want to copy the command lines below and go ahead and replace all the items in [ ] brackets with the correct information.

Set up SSH Keys
---------------

https://www.digitalocean.com/community/articles/how-to-set-up-ssh-keys--2

Hit enter after each command. Assume you haven’t already created SSH keys yet, on your computer:

    ssh-keygen -t rsa

Hit enter at file and passphrase prompts.

    sudo vi ~/.ssh/id_rsa.pub

1. Copy contents of file.
2. At Digital Ocean dashboard, go to SSH keys.
3. Click the “Add SSH Key” button
4. Give the key a name and paste in the key into the Public SSH Key field.
5. Click the “Create SSH Key” button
6. Go to Droplets
7. Click the Create Droplet button
8. Select options for your droplet, be sure to select the SSH Key

Initial Server Setup
---------------

https://www.digitalocean.com/community/articles/initial-server-setup-with-centos-6

    ssh root@[your server's IP address]
    echo -e "[your password]\n[your password]" | passwd

Paste in new root password at each prompt

    vi setup.sh
    
Paste in the following lines:

    #!/bin/bash
    read -p "Please enter the new username: " username
    read -p "Please enter the new user password: " userpassword
    adduser $username
    echo -e "$userpassword\n$userpassword" | passwd $username
    echo $username'	ALL=(ALL)	ALL' >> /etc/sudoers
    sed -i 's/#Port 22/Port 880/g' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin yes/PermitRootLogin without-password/g' /etc/ssh/sshd_config
    sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
    echo "AllowUsers $username" >> /etc/ssh/sshd_config
    /etc/init.d/sshd reload

Press Escape, then Shift ZZ to save and exit the file.

    chmod +x setup.sh
    ./setup.sh

On your computer, open Terminal and type:

    sudo vi ~/.ssh/id_rsa.pub

Copy the contents of this file.   
Open another tab in Terminal

    ssh -p 880 [your username]@[your server's IP address]
    sudo vi initialsetup.sh
    
Paste in the following lines:

    #!/bin/bash
    scriptloop="y"
    while [ "$scriptloop" = "y" ]; do
    echo -e  ""
    echo -e  ""
    echo -e  "Server Setup:"
    echo -e  ""
    echo -e  "1 - Add SSH keys"
    echo -e  "2 - Create git Keys"
    echo -e  "3 - Check github connection"
    echo -e  "4 - Build, install, and configure git"
    echo -e  "5 - Clone slushhost github repo"
    echo -e  ""
    echo -e  "q - Exit Installers"
    echo -e  ""
    echo -e  "Please enter NUMBER of choice (example: 3):"
    read choice
    case $choice in
    1)
    sudo mkdir -p ~/.ssh
    echo -e "Paste in the contents of the id_rsa.pub file from your local computer."
    read -p "Hit enter to paste the SSH key."
    sudo vi ~/.ssh/authorized_keys
    ;;
    2)
    sudo chown $USER /home/$USER ~/.ssh ~/.ssh/authorized_keys
    sudo chmod go-w /home/$USER ~/.ssh ~/.ssh/authorized_keys
    read -p "Please enter your email address: " email
    sudo ssh-keygen -f ~/.ssh/id_rsa -t rsa -C "$email" -N ''
    sudo chown $USER:$USER ~/.ssh/id_rsa
    sudo chown $USER:$USER ~/.ssh/id_rsa.pub
    sudo chmod 0700 ~/.ssh/id_rsa
    sudo chmod 0700 ~/.ssh/id_rsa.pub
    echo -e "Copy the following SSH key"
    echo -e "Go to Github, click the Edit Your Profile button, and go to SSH keys"
    echo -e "Click the Add SSH Key button, paste in the SSH key and give it a name."
    echo -e "Click the Add Key button."
    echo -e "When your finished, on server, press escape, then Shift ZZ to save and exit the file."
    read -p "Hit enter to see the SSH key."
    sudo vi ~/.ssh/id_rsa.pub
    ;;
    3)
    ssh -T git@github.com
    ;;
    4)
    sudo yum -y groupinstall "Development Tools"
    sudo yum -y install zlib-devel perl-ExtUtils-MakeMaker asciidoc xmlto openssl-devel
    wget -O git.zip https://github.com/git/git/archive/master.zip
    unzip git.zip
    cd git-master
    make configure
    ./configure --prefix=/usr/local
    make all doc
    sudo make install install-doc install-html  
    read -p "Please enter the user name to use for git: " gituser
    read -p "Please enter the email address to use for git: " gitemail
    sudo git config --global user.name "$gituser"
    sudo git config --global user.email "$gitemail"
    sudo git config --list
    ;;
    5)
    cd
    git clone git@github.com:slushman/slushhost.git
    sudo chmod +x slushhost/installs.sh
    sudo chmod +x slushhost/managesites.sh
    sudo chmod +x slushhost/selinux.sh
    sudo mv -f slushhost/bash_profile.txt ~/.bash_profile
    ./slushhost/installs.sh
    ;;
    q)
    scriptloop="n"
    ;;
    *)
    echo - "Unknown choice! Exiting..."
    ;;
    esac
    done

Press Escape, then Shift ZZ to save and exit the file.  

    sudo chmod +x initialsetup.sh
    ./initialsetup.sh

MariaDB
---------------

After running the installs bash script for MariaDB:

Hit enter to bypass the initial password prompts.   
Hit y to setup a password for MySQL
Paste in MySQL root password at each prompt
Say yes to all options   
Paste in MySQL root password
Paste in MySQL username
Paste in MySQL user password
Hit the up arrow to get the last command again, this time, choose option 4

Install & Config SELinux
---------------

To install and configure SELinux, run this command:

	./slushhost/selinux.sh

Run each option in order. The server will reboot after each option. Wait about 60 seconds, then hit the up arrow to get the login command again. Once you've reconnected to the server, hit the up arrow again to reopen the SE Linux config script.

Manage Sites
---------------

To check the SE Linux stats, add sites, install WordPress, import and export databases, and move sites from another server, run this command:

    ./slushhost/managesites.sh
 

 
 
 
 
 
 
 
----------------
ToDo List:

1) Research more secure iptables config



2) Backups?

https://www.webniraj.com/2013/03/24/using-amazon-s3-to-backup-your-server/

3) Connect SELinux and nginx - not currently working for CentOS 6

not yet - wait for this to work properly with CentOS 6

    sudo yum -y install selinux-policy-targeted selinux-policy-devel
    cd /opt
    sudo wget 'http://downloads.sourceforge.net/project/selinuxnginx/se-ngix_1_0_10.tar.gz?use_mirror=nchc' 
    sudo tar -zxvf se-ngix_1_0_10.tar.gz
    cd se-ngix_1_0_10/nginx
    sudo make
    sudo /usr/sbin/semodule -i nginx.pp 
