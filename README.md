# fix-ssh-on-pi

## Safely enabling ssh in the default Raspberry Pi OS (previously called Raspbian) Image

This script will make some small but necessary changes to a default [Raspberry Pi OS (previously called Raspbian)](https://www.raspbian.org/) image. 

In episode [hpr2356 :: Safely enabling ssh in the default Raspbian Image](http://hackerpublicradio.org/eps.php?id=2356) I walked through the first steps of automating the update of this base image. It will:

- Download the latest image zip file
- Verify it is valid
- Extract the image itself
- Enable ssh for secure remote management
- Change the default passwords for the root and pi user  
  Generate encrypted + shell escaped password string using `encrypted=$(openssl passwd -6) bash -c 'printf "%q\n" "${encrypted}"'`
- Secure the ssh server on the Pi

Since then I improved the script to:

- Enable connections to your WiFi network (wpa_supplicant.conf)
- Load it's configuration from a ini file keeping sensitive information separate from the main script.
- Using [losetup](http://man7.org/linux/man-pages/man8/losetup.8.html) to greatly simplify the mounting of the image.
- Creation of a [First Boot](https://github.com/nmcclain/raspberian-firstboot) script.

This script is part of a series "Manage your Raspberry Pi fleet with Ansible" which was covered on [opensource.com](https://opensource.com/article/20/9/raspberry-pi-ansible) and on [Hacker Public Radio](http://hackerpublicradio.org/eps.php?id=3173).
