#!/bin/bash
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

# Fix to ignore more networks.

parent='all_pies' # The section where you group your RaspberryPi's

##################################################
# Editing below this line should not be necessary

if [ $(id | grep 'uid=0' | wc -l) -ne 1 ]
then
    echo "Error: You need to be root"
    exit 1
fi

echo "[${parent}]" 

if [ $( which arp-scan 2>/dev/null | wc -l ) -eq 1 ]
then
  ifconfig | awk -F ':' '/: flags/ {print $1}' | grep -vE 'lo|loop|docker|ppp|vmnet' | while read interface
  do
    arp-scan --quiet --interface ${interface} --localnet --numeric --ignoredups 2>/dev/null | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}.*([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2}"
  done
else
  base=$(route -n | egrep '^0.0.0.0' | awk '{print $2}' | awk -F '.' '{print $1"."$2"."$3}')
  for node in {1..254}
      do ( ping -n -c 1 -W 1 ${base}.${node} >/dev/null 2>&1 & )
  done
  arp -n | grep ether | awk '{print $1" "$3}' 
fi | grep -iE 'b8:27:eb|dc:a6:32' | sort | while read ip mac
do
  host_name=$( awk '/nameserver/ {print $2}' /etc/resolv.conf | while read nameserver
  do 
    host ${ip}c ${nameserver}
  done | grep pointer | head -1 | awk '{print $NF}' )

  if [ -z "${host_name}" ]
  then
    host_name=$( grep ${ip} /etc/hosts | awk '{print $2}' | head -1)
  fi
  
  if [ -z "${host_name}" ]
  then
    host_name="$( echo ${mac} | sed 's/://g' )"
  fi
  
  echo "${host_name} ansible_host=${ip}"
done
