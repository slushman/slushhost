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