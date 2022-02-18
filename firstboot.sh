#!/bin/bash
sleep 2m
macadd=$(ip -brief add | awk '/UP/ {print $1}' | sort | head -1)
if [ ! -z "${macadd}" ]; then
  macadd=$(sed 's/://g' /sys/class/net/${macadd}/address)
  sed "s/raspberrypi/${macadd}/g" -i /etc/hostname /etc/hosts
fi

# You can customise the system here :
# Put the minimal stuff, prefer to use ansible to install/configure yours raspberry !
sudo apt update && apt upgrade -y
sudo apt install -y raspi-config

sudo raspi-config nonint do_boot_behaviour B1 # Boot to cli (no  gui) & require login (no autologin)
sudo raspi-config nonint do_boot_wait 0       # Turn off waiting for network before booting

# Other system configuration examples :
# sudo raspi-config nonint do_change_timezone Europe/Paris
# sudo raspi-config nonint do_change_locale fr_FR.UTF-8
# sudo raspi-config nonint do_configure_keyboard fr

/sbin/shutdown -r 5 "reboot in Five minutes"
