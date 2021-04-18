#!/bin/bash

max_vms=4
for i in $(seq 1 $max_vms); do
  echo "-x-x-x- mhost$i -x-x-x-"
  ssh-copy-id ansible@mhost_base || echo "-x-x-x- check network/vm status -x-x-x-"
  ansible mhost_base -b -o -m lineinfile -a "path=/etc/sysconfig/network-scripts/ifcfg-ens33 regexp=^IPADDR line=IPADDR=192.168.1.20$i"
  ansible mhost_base -b -o -m lineinfile -a 'path=/etc/bashrc insertbefore="# vim:ts=4:sw=4" line="set -o vi"'
  ansible mhost_base -b -o -m lineinfile -a 'path=/etc/selinux/config regexp="^SELINUX=e" line="SELINUX=disabled"'
  ansible mhost_base -b -o -m hostname -a "name=mhost$i"
  ansible mhost_base -b -a 'reboot'
  echo 
  echo "-x-x-x- mhost$i is done and booting -x-x-x-"
  if [ $i -lt $max_vms ]; then
    chars="/-\|"
    timer=3
    while [ $timer != 0 ]; do
      for (( j=0; j<${#chars}; j++)); do
        sleep 0.5
        echo -en "${chars:$j:1}" "\r"
      done
      timer=$(echo $timer - 0.5 | bc)
    done
      echo "-x-x-x- waiting for mhost$(expr $i + 1) to power up -x-x-x-"
      while ping -t1 -c1 mhost_base > /dev/null 2>&1 ; (($?)); do
        echo -n "."
      done
      echo
  fi
done

echo "-x-x-x- testing the hosts with ansible facts -x-x-x-"
if [ $(which jq 2>/dev/null) ]; then
  ANSIBLE_LOAD_CALLBACK_PLUGINS=true
  ANSIBLE_STDOUT_CALLBACK=json
  #ansible -m setup mhost1 | jq "$stat,$ipv4"
  for i in $(seq 1 $max_vms); do
    stat=".stats.mhost$i.ok"
    hostname=".plays[].tasks[].hosts.mhost$i.ansible_facts.ansible_hostname"
    ipv4=".plays[].tasks[].hosts.mhost$i.ansible_facts.ansible_default_ipv4.address"
    selinux=".plays[].tasks[].hosts.mhost$i.ansible_facts.ansible_selinux.status"
    ansible -m setup mhost$i | jq "$hostname , $ipv4 , $selinux"
  done
else
  ansible mhost_general -m ping -o
fi

