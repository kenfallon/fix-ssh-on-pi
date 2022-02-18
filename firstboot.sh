#!/bin/bash
sleep 2m
macadd=$(ip -brief add | awk '/UP/ {print $1}' | sort | head -1)
if [ ! -z "${macadd}" ]; then
  macadd=$(sed 's/://g' /sys/class/net/${macadd}/address)
  sed "s/raspberrypi/${macadd}/g" -i /etc/hostname /etc/hosts
fi

# FIXME : Put all theses rapi-config in another bash script `raspi-config.sh.example`
# Set a conditionnal launch only if `raspi-config.sh` exist here.

# set boot options
# sudo raspi-config nonint do_boot_behaviour B1 # Boot to CLI & require login
# sudo raspi-config nonint do_boot_wait 0       # Turn off waiting for network before booting
# sudo raspi-config nonint do_memory_split 16   # Set the GPU memory limit to 16MB

# System Configuration. Can also be done after with ansible
# sudo raspi-config nonint do_change_timezone Europe/Paris
# sudo raspi-config nonint do_change_locale fr_FR.UTF-8
# sudo raspi-config nonint do_configure_keyboard fr

# upgrade packages and set hostname
# sudo apt update && upgrade -y
# sudo apt install -y raspi-config vim

/sbin/shutdown -r 5 "reboot in Five minutes"
