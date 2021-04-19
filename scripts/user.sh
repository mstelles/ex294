#!/bin/bash

ansible all -b -m group -a "name=ex294 state=present"
ansible all -b -m user -a "name=rhce password='{{'rhce_pass' | password_hash('sha512') }}' uid='2021' group='ex294' append=true"
