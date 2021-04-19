#!/bin/bash

ansible prod -b -m file -a 'path=/root/redhat/ex294 state=directory recurse=true'
ansible prod -b -m file -a 'path=/root/redhat/ex294/results mode="g=rwx,o=rx" owner="mark" state=touch' 
ansible prod -b -m file -a 'src=/root/redhat/ex294/results dest=/root/results state=link'
