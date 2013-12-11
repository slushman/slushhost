#!/bin/bash
scriptloop="y"
while [ "$scriptloop" = "y" ]; do
echo -e  ""
echo -e  ""
echo -e  "SELinux Setup:"
echo -e  ""
echo -e  "1 - Download and install"
echo -e  "2 - Set config"
echo -e  "3 - Start SELinux"
echo -e  "4 - Get SE Linux status"
echo -e  "5 - Manage Sites"
echo -e  ""
echo -e  "q - Exit SELinux Setup"
echo -e  ""
echo -e  "Please enter NUMBER of choice (example: 3):"
read choice
case $choice in



1)
sudo yum -y install policycoreutils setroubleshoot
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



4)
sudo sestatus
;;



5)
./slushhost/managesites.sh
scriptloop="n"
;;



q)
scriptloop="n"
;;

*)
echo - "Unknown choice! Exiting..."
;;

esac
done