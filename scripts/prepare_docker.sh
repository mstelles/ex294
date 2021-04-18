#!/bin/bash

echo "Purging and relaunching the mhost* containers"
for i in $(seq 1 4); do
  docker container stop mhost$i > /dev/null 2>&1 && docker container rm mhost$i > /dev/null 2>&1 || echo "mhost$i container doesnt exit, will create"
  docker container run -dt --name mhost$i mstelles/multi-centos8:latest
  sleep 0.5s
done
ansible -m ping -o all
