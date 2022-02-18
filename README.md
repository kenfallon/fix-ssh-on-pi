# fix-ssh-on-pi

## Safely enabling ssh in the default Raspberry Pi OS (previously called Raspbian) Image

This script will make some small but necessary changes to a default [Raspberry Pi OS (previously called Raspbian)](https://www.raspbian.org/) image. 

In episode [hpr2356 :: Safely enabling ssh in the default Raspbian Image](http://hackerpublicradio.org/eps.php?id=2356) I walked through the first steps of automating the update of this base image. It will:

- Download the latest image zip file
- Verify it is valid
- Extract the image itself
- Enable ssh for secure remote management
- Change the default passwords for the root and pi user
- Secure the ssh server on the Pi

Since then I improved the script to:

- Enable connections to your WiFi network (wpa_supplicant.conf)
- Load it's configuration from a ini file keeping sensitive information separate from the main script.
- Using [losetup](http://man7.org/linux/man-pages/man8/losetup.8.html) to greatly simplify the mounting of the image.
- Creation of a [First Boot](https://github.com/nmcclain/raspberian-firstboot) script.

This script is part of a series "Manage your Raspberry Pi fleet with Ansible" which was covered on [opensource.com](https://opensource.com/article/20/9/raspberry-pi-ansible) and on [Hacker Public Radio](http://hackerpublicradio.org/eps.php?id=3173).

## Easy usage/setup with docker : 

### Retrieve everything :

If you're using mac or any system that does not support `losetup`, this can be a little bit painful to use.

Here's a process setup everything easily :

```
git clone git@github.com:kenfallon/fix-ssh-on-pi.git
cd fix-ssh-on-pi
```

### Create a new ssh key for the Raspberry Pi :

```
docker run -v $(pwd):/data debian:stable /bin/bash -c "apt update && apt install -y openssh-client && mkdir /data/.ssh && ssh-keygen -t ed25519 -N '' -f /data/.ssh/raspberry-key-ed25519 -C 'Raspberry Pi keys'"
```

### Edit configuration files :

```
cp wpa_supplicant.conf_example wpa_supplicant.conf
cp fix-ssh-on-pi.ini_example fix-ssh-on-pi.ini
```

You should now edit both `wpa_supplicant.conf` and `fix-ssh-on-pi.ini` with the values that fits your need. 

Example for `fix-ssh-on-pi.ini`  :

```
root_password_clear='CHANGEME'
pi_password_clear='CHANGEME'
public_key_file='/data/.ssh/raspberry-key-ed25519.pub'
wifi_file='/data/wpa_supplicant.conf'
first_boot='firstboot.sh'
os_variant='full'
```

### Generate the image with ssh enabled :

```
docker run -ti --privileged -v /dev:/dev -v $(pwd):/data --workdir /data debian:stable /bin/bash -c "apt update && apt install -y build-essential net-tools wget p7zip-full python3 && bash /data/fix-ssh-on-pi.bash"
```

Note : the ugly option `-v /dev:/dev` seem to be needed (check [here](https://github.com/moby/moby/issues/27886) for more information). Without that, the losetup command does not successfully retrieve the partition table and create device.

### Burn the image on a sd card :

You can now burn the new file that finish by `-ssh-enabled.img` with the tool of your choice, insert the sdcard into your raspberry and launch it.

Please check [index.md](https://github.com/kenfallon/fix-ssh-on-pi/blob/master/index.md).

TLDR; here is an example with dd :

```
sudo fdisk -l 	   //  lists all the disks & partitions to get path of the sdcard
sudo diskutil list // Same on Mac
dd bs=4M if=FIXME-ssh-enabled.img of=/path/to/disk status=progress`
```

### Setup the inventory for ansible :

```
sudo bash put-pi-in-ansible-host.bash  | tee all_pies.ini

cat >> all_pies.ini <<- EOM
[all_pies:vars]
ansible_connection=ssh
ansible_ssh_user=pi
ansible_ssh_private_key_file=./.ssh/raspberry-key-ed25519
EOM
```

### Check if everything work :

```
hostname="$(cat all_pies.ini | grep ansible_host | awk '{print $1}' | head -n1).local"
ssh -i .ssh/raspberry-key-ed25519 pi@$hostname

ansible-playbook --inventory-file all_pies.ini ping-example-playbook.yaml
```
