#!/usr/bin/env bash
# MIT License
# Copyright (c) 2017 Ken Fallon http://kenfallon.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# v1.1 - changes to reflect that the sha_sum is now SHA-256
# v1.2 - Changes to split settings to different file, and use losetup
# v1.3 - Removed requirement to use xmllint (Thanks MachineSaver)
#        Added support for wifi mac naming (Thanks danielo515)
#        Moved ethernet naming to firstboot.sh
# v1.4 - Removed option to encrypt clear password. It's more secure to keep store
#        the hash anyway. Thanks tillhanke
# v1.5 - Thanks David G
#        Introduced functions for common tasks
#        Moved creation of the passwords and accounts to the ini file
#        Added support to select which Raspberry_Pi_OS Version to download
#        Added support set up default users using userconf.txt
# v1.5.1 Fix checking userconf.txt
#        
#        
#        

# Credits to:
# - Dave Morriss http://hackerpublicradio.org/correspondents.php?hostid=225
# - In-Depth Series: Bash Scripting https://hackerpublicradio.org/series.php?id=42
# - https://gpiozero.readthedocs.io/en/stable/pi_zero_otg.html#legacy-method-sd-card-required
# - https://github.com/nmcclain/raspberian-firstboot
# - https://gist.github.com/magnetikonline/22c1eb412daa350eeceee76c97519da8

# Settings are made in the settings file (eg fix-ssh-on-pi.ini)

###########
# Functions
#
echo_error() {
  echo -e "ERROR: $@" #1>&2
}

echo_debug() {
  if [ "${debug}" != "0"  ]
  then
    echo -e "INFO: $@" #1>&2
  fi
}

function umount_sdcard () {
  sdcard_mount="$@"
  echo_debug "Unmounting ${sdcard_mount}"
  sync
  umount_response=$( umount --verbose "${sdcard_mount}" 2>&1 )
  if [ $( ls -al "${sdcard_mount}" | wc -l ) -eq "3" ]
  then
      echo_debug "Sucessfully unmounted \"${sdcard_mount}\""
      sync
  else
      echo_error "Could not unmount \"${sdcard_mount}\": ${umount_response}"
      exit 4
  fi
}

function check_tool() {
  command -v "${1}" >/dev/null 2>&1
  if [[ ${?} -ne 0 ]]
  then
    echo_error "Can't find the application \"${1}\" installed on your system."
    exit 11
  fi
}

###########
# Variables
#
download_site="https://downloads.raspberrypi.org"

###########
# Checks
#
if [ $(id | grep 'uid=0(root)' | wc -l) -ne "1" ]
then
  echo_error "You are not root and some programs (losetup) require it to work"
  exit 12
fi

for this_tool in 7z awk basename cat cd chmod chown command cp curl declare hash echo eval exit grep id ln losetup ls mkdir mount mv rm rmdir sed sha256sum sync touch tr umount wc
do
  check_tool "${this_tool}"
done

settings_file="fix-ssh-on-pi.ini"

if [ -e "${settings_file}" ]
then
  settings_file="${settings_file}"
elif [ -e "${HOME}/${settings_file}" ]
then
  settings_file="${HOME}/${settings_file}"
elif [ -e "${HOME}/.config/${settings_file}" ]
then
  settings_file="${HOME}/.config/${settings_file}"
elif [ -e "${0%.*}.ini" ]
then
  settings_file="${0%.*}.ini"
else
  echo_error "Can't find the Settings file \"${settings_file}\""
  exit 1
fi

if [ "$( grep -ic CHANGEME "${settings_file}" 2>/dev/null )" -ne 0 ]
then
  echo_error "The required changes have not been made to the \""${settings_file}"\" file."
  echo_error "The following variables need to be changed:"
  grep -i CHANGEME "${settings_file}" | awk -F '=' '{print $1}' #1>&2
  exit 13
fi

source "${settings_file}"
echo_debug "Finished loading the settings file \"${settings_file}\""

# These variables need to be set in the settings file
variables=(
  architecture
  debug
  first_boot
  generation
  os_version
  pi_password_hash
  public_key_file
  root_password_hash
  wifi_file
  working_dir
)

for variable in "${variables[@]}"
do
  if [[ -z ${!variable+x} ]]
  then   # indirect expansion here
    echo_error "The variable \"${variable}\" is missing from your \""${settings_file}"\" file.";
    exit 2
  fi
done

if [ $# -gt 0 ]
then
  declare -A hash
  for argument
  do
    if [[ $argument =~ ^[^=]+=.*$ ]]
    then
      key="${argument%=*}"
      value="${argument#*=}"
      eval "${key}=${value}"
    fi
  done
fi

echo_debug "Requesting  \"${generation}\", \"${os_version}\", \"${architecture}\" "

if [ ! -e "${userconf_txt_file}" ]
then
  echo_error "Can't find the userconf.txt file \"${userconf_txt_file}\""
  echo_error "This file should contain a single line of text, consisting of username:encryptedpassword."
  echo_error "Where the encrypted password is created using:"
  echo_error "   echo 'mypassword' | openssl passwd -6 -stdin"
  exit 3
fi

if [ "$( grep -ic CHANGEME "${userconf_txt_file}" 2>/dev/null )" -ne 0 ]
then
  echo_error "The required changes have not been made to the \""${userconf_txt_file}"\" file."
  echo_error "The following variables need to be changed:"
  grep -i CHANGEME "${userconf_txt_file}" | awk -F '=' '{print $1}' #1>&2
  exit 13
fi


if [ ! -e "${public_key_file}" ]
then
  echo_error "Can't find the public key file \"${public_key_file}\""
  echo_error "You can create one using:"
  echo_error "   ssh-keygen -t ed25519 -f ./${public_key_file} -C \"Raspberry Pi keys\""
  exit 3
fi

if [ ! -e "${wifi_file}" ]
then
  echo_error "Can't find the wpa_supplicant.conf file \"${wifi_file}\""
  echo_error "You can modify the one provided here:"
  echo_error "   https://github.com/kenfallon/fix-ssh-on-pi/blob/master/wpa_supplicant.conf_example"
  exit 14
fi

if [ ! -e "${first_boot}" ]
then
  echo_error "Can't find the first boot script file \"${first_boot}\""
  echo_error "You can use or modify the one provided here:"
  echo_error "   https://github.com/kenfallon/fix-ssh-on-pi/blob/master/firstboot.sh"
  exit 15
fi

if [ ! -d "${working_dir}" ]
then
  echo_error "The working directory \"${working_dir}\" is not a directory."
  exit 16
fi

touch "${working_dir}/~test" >/dev/null 2>&1
if [ "$?" != "0" ]
then
  echo_error "Cannot write to the working directory \"${working_dir}\"."
  exit 17
fi
rm "${working_dir}/~test"

###########
# Decide which disto to use
#
# generation can be either Legacy, or Current
generation=$(echo ${generation} | tr '[:upper:]' '[:lower:]')
if [ "${generation}" == "legacy" ]
then
  generation_path="oldstable_"
else
  generation_path=""
fi

# version can be either Lite, Medium, or Full
os_version=$(echo ${os_version} | tr '[:upper:]' '[:lower:]')
if [ "${os_version}" == "medium" ]
then
  os_version_path=""
else
  os_version_path="${os_version}_"
fi

# architecture can be either armhf, or arm64
architecture=$(echo ${architecture} | tr '[:upper:]' '[:lower:]')

shortcut_url="${download_site}/raspios_${generation_path}${os_version_path}${architecture}_latest"
shortcut_url_response=$( curl --silent "${shortcut_url}" --head )
# find the redirect url and remove color formatting
download_url=$( echo "${shortcut_url_response}" | grep location | sed -e 's/^.*https:/https:/g' -e 's/xz.*$/xz/g' )

###########
# Download the image and checksum files
#
if [[ -z ${download_url} ]]
then
  echo_error "Could not find a download URL for \"${shortcut_url}\".";
  exit 21
else
  echo_debug "The latest image will be retrieved from ${download_url}"
  downloaded_image=$( basename ${download_url} )
  downloaded_image_path="${working_dir}/${downloaded_image}"
  curl --silent --head "${download_url}" | sed -e "s/\r//g" > "${downloaded_image_path}.head"
  download_url_content_length=$( awk  '/content-length: / {print $2}' "${downloaded_image_path}.head" )
  if [ -f "${downloaded_image_path}" ]
  then
    if [ "${download_url_content_length}" -ne "$( ls -al "${downloaded_image_path}" | awk '{print $5}' )" ]
    then
      curl --continue-at - "${download_url}" --output "${downloaded_image_path}"
    else
      echo_debug "Skipping download of ${downloaded_image}"
    fi
  else
    curl --continue-at - "${download_url}" --output "${downloaded_image_path}"
  fi
  if [ ! -f "${downloaded_image_path}.sha256.ok" ]
  then
    echo_debug "Checking to see if the sha256 of the downloaded image match \"${downloaded_image}.sha256\""
    curl --silent "${download_url}.sha256" --output "${downloaded_image_path}.sha256"
    if [ "$( grep -c "$( sha256sum "${downloaded_image_path}" | awk '{print $1}' )" "${downloaded_image_path}.sha256" )" -eq "1" ]
    then
        echo_debug "The sha256 match \"${downloaded_image}.sha256\""
        mv "${downloaded_image_path}.sha256" "${downloaded_image_path}.sha256.ok"
    else
        echo_error "The sha256 did not match \"${downloaded_image}.sha256\""
        exit 5
    fi
  else
    echo_debug "Skipping check of sha256 of the downloaded image match as \"${downloaded_image}.sha256.ok\" file found."
  fi
fi

###########
# Extract the image files
#
extracted_image_path=$( echo "${downloaded_image_path}" | sed 's/\.xz//g' )
extracted_image=$( basename ${extracted_image_path} )
echo_debug "Extracting the image as \"${extracted_image_path}\""
7z x -y "${downloaded_image_path}" -o"${working_dir}"

if [ ! -e "${extracted_image_path}" ]
then
    echo_error "Can't find the image \"${extracted_image_path}\""
    exit 6
fi

###########
# Mount and change boot partition P1 files
#
sdcard_mount_p1="${working_dir}/${extracted_image}_sdcard_mount_p1"
if [ -d "${sdcard_mount_p1}" ]
then
  rmdir "${sdcard_mount_p1}"
fi

if [ -d "${sdcard_mount_p1}" ]
then
  echo_debug "Cannot remove the old mount point \"${sdcard_mount_p1}\""
  exit 20
fi
mkdir -v "${sdcard_mount_p1}"

echo_debug "Mounting the sdcard boot disk \"${sdcard_mount_p1}\""

loop_base=$( losetup --partscan --find --show "${extracted_image_path}" )

echo_debug "Mounting \"${loop_base}p1\" to \"${sdcard_mount_p1}\" "
mount ${loop_base}p1 "${sdcard_mount_p1}"
if [ ! -d "${sdcard_mount_p1}/overlays" ]
then
  echo_error "Can't find the mounted card \"${sdcard_mount_p1}\""
  exit 7
fi

cp "${userconf_txt_file}" "${sdcard_mount_p1}/userconf.txt"
if [ -e "${sdcard_mount_p1}/userconf.txt" ]
then
  echo_debug "The userconf.txt file \"${userconf_txt_file}\" has been copied"
else
  echo_error "Can't find the userconf.txt file \"${sdcard_mount_p1}/userconf.txt\""
  exit 22
fi

cp "${wifi_file}" "${sdcard_mount_p1}/wpa_supplicant.conf"
if [ -e "${sdcard_mount_p1}/wpa_supplicant.conf" ]
then
  echo_debug "The wifi file \"${wifi_file}\" has been copied"
else
  echo_error "Can't find the wpa_supplicant file \"${sdcard_mount_p1}/wpa_supplicant.conf\""
  exit 8
fi

touch "${sdcard_mount_p1}/ssh"
if [ -e "${sdcard_mount_p1}/ssh" ]
then
  echo_debug "The ssh config file has been copied"
else
  echo_error "Can't find the ssh file \"${sdcard_mount_p1}/ssh\""
  exit 9
fi

if [ -e "${first_boot}" ]
then
  cp "${first_boot}" "${sdcard_mount_p1}/firstboot.sh"
  if [ -e "${sdcard_mount_p1}/firstboot.sh" ]
  then
    echo_debug "The first boot script been copied"
  else
    echo_error "Can't find the first boot script file \"${sdcard_mount_p1}/firstboot.sh\""
    exit 19
  fi
fi

umount_sdcard "${sdcard_mount_p1}"
losetup --verbose --detach ${loop_base}
rmdir -v "${sdcard_mount_p1}"

###########
# Mount and change boot partition P2 files
#
sdcard_mount_p2="${working_dir}/${extracted_image}_sdcard_mount_p2"

if [ -d "${sdcard_mount_p2}" ]
then
  rmdir "${sdcard_mount_p2}"
fi

if [ -d "${sdcard_mount_p2}" ]
then
  echo_debug "Cannot remove the old mount point \"${sdcard_mount_p2}\""
  exit 18
fi
mkdir -v "${sdcard_mount_p2}"

echo_debug "Mounting the sdcard root disk \"${sdcard_mount_p2}\""

loop_base=$( losetup --partscan --find --show "${extracted_image_path}" )

echo_debug "Mounting \"${loop_base}p2\" to \"${sdcard_mount_p2}\" "
mount ${loop_base}p2 "${sdcard_mount_p2}"
if [ ! -e "${sdcard_mount_p2}/etc/shadow" ]
then
    echo_error "Can't find the mounted card\"${sdcard_mount_p2}/etc/shadow\""
    exit 10
fi

echo_debug "Change the passwords and sshd_config file"

sed -e "s#^root:[^:]\+:#root:${root_password_hash}:#" "${sdcard_mount_p2}/etc/shadow" -e  "s#^pi:[^:]\+:#pi:${pi_password_hash}:#" -i "${sdcard_mount_p2}/etc/shadow"
sed -e 's;^#PasswordAuthentication.*$;PasswordAuthentication no;g' -e 's;^PermitRootLogin .*$;PermitRootLogin no;g' -i "${sdcard_mount_p2}/etc/ssh/sshd_config"
mkdir "${sdcard_mount_p2}/home/pi/.ssh"
chmod 0700 "${sdcard_mount_p2}/home/pi/.ssh"
chown 1000:1000 "${sdcard_mount_p2}/home/pi/.ssh"
cat ${public_key_file} >> "${sdcard_mount_p2}/home/pi/.ssh/authorized_keys"
chown 1000:1000 "${sdcard_mount_p2}/home/pi/.ssh/authorized_keys"
chmod 0600 "${sdcard_mount_p2}/home/pi/.ssh/authorized_keys"

echo "[Unit]
Description=FirstBoot
After=network.target
Before=rc-local.service
ConditionFileNotEmpty=/boot/firstboot.sh

[Service]
ExecStart=/boot/firstboot.sh
ExecStartPost=/bin/mv /boot/firstboot.sh /boot/firstboot.sh.done
Type=oneshot
RemainAfterExit=no

[Install]
WantedBy=multi-user.target" > "${sdcard_mount_p2}/lib/systemd/system/firstboot.service"

cd "${sdcard_mount_p2}/etc/systemd/system/multi-user.target.wants" && ln -s "/lib/systemd/system/firstboot.service" "./firstboot.service"
cd -

umount_sdcard "${sdcard_mount_p2}"
losetup --verbose --detach ${loop_base}
rmdir -v "${sdcard_mount_p2}"

###########
# Cleanup and end
#
new_name="${extracted_image_path%.*}-ssh-enabled.img"
mv -v "${extracted_image_path}" "${new_name}"

echo_debug ""
echo_debug "Now you can burn the disk using something like:"
echo_debug "      dd bs=4M status=progress if=${new_name} of=/dev/mmcblk????"
echo_debug ""
