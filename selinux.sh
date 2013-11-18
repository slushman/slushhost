#!/bin/bash
scriptloop="y"
while [ "$scriptloop" = "y" ]; do
echo -e  "SELinux Setup:"
echo -e  ""
echo -e  "1 - Download and install"
echo -e  "2 - Set config"
echo -e  "3 - Create a new MySQL user"
echo -e  ""
echo -e  "q - EXIT MYSQL SCRIPT!"
echo -e  ""
echo -e  "Please enter NUMBER of choice (example: 3):"
read choice
case $choice in

1)
sudo yum install policycoreutils setroubleshoot
sudo sed -i 's/SELINUX=disabled/SELINUX=permissive/g' /etc/selinux/config
sudo reboot
;;

2)
sudo restorecon -Rv -n /home
sudo restorecon -Rv -n /
sudo touch /.autorelabel
sudo reboot
;;

3)
sudo sed -i 's/SELINUX=permissive/SELINUX=enforcing/g' /etc/selinux/config
sudo egrep -i 'selinux=0|enforcing=0' /boot/grub/grub.conf
sudo semanage port -a -t ssh_port_t -p tcp 25000
sudo reboot
;;

q)
scriptloop="n"
;;

*)
echo - "Unknown choice! Exiting..."
;;

esac
done