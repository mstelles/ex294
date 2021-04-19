## Personal stuff created to prepare to my [EX294](https://www.redhat.com/en/services/training/ex294-red-hat-certified-engineer-rhce-exam-red-hat-enterprise-linux-8)  exam.

Feel free to use if you like but don't take this as a course for the certification.

### ========== pre tasks ==========

#### 1. Lab Setup:
- Centos8
- 5 vms:
  - 1 control node
  - 4 managed nodes with:
    - Centos8, minimal install
    - disk: 30GB
      - /boot: 300MiB
      - /home: 10GiB
      - /: 12GiB
      - 7.71 GiB free
    - mem: 1GB

- I used the 192.168.1.0/24 network on my tests and then added the appropriate mhost<num> entries in /etc/hosts.

```bash
192.168.1.200  mhost_base
192.168.1.201	mhost1
192.168.1.202	mhost2
192.168.1.203	mhost3
192.168.1.204	mhost4
```

#### 2. Structure
  - Playbooks: ~ansible/tasks/playbooks
    - Every command should br executed from ~ansible/tasks directory.
  - Scripts: ~ansible/tasks/scripts
  - Roles: ~ansible/tasks/roles

#### 3. Tips:
  - Keep in mind the 'ansible-doc <module_name>' command.
  - Use the setup module to check the available facts, keeping in mind:
    - Use the -b option to gather all variables, when needed.
    - Consider using 'gather_subset' when possible, this will create less overhead on the execution.
    - The filter option will work only for second level variables and further values would be ignored. This only applies when running ad-hoc commands. During playbook execution this restriction doesn't exist.
  - When running playbooks, keep in mind the options:
    - --syntax-check
    - --step
    - --start-at-task
    - --force-handlers
    - --list-tasks

Ex:

This will show the 'ansible_default_ipv4' dictionary.
```json
$ ansible -b mhost1 -m setup -a 'gather_subset=network filter=ansible_default_ipv4'
mhost1 | SUCCESS => {
    "ansible_facts": {
        "ansible_default_ipv4": {
            "address": "192.168.1.201",
            "alias": "ens33",
            "broadcast": "192.168.1.255",
            "gateway": "192.168.1.1",
            "interface": "ens33",
            "macaddress": "00:0c:29:f9:b2:70",
            "mtu": 1500,
            "netmask": "255.255.255.0",
            "network": "192.168.1.0",
            "type": "ether"
        },
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false

```

This won't return any fact.
```json
$ ansible -b mhost1 -m setup -a 'gather_subset=network filter=ansible_default_ipv4.address'
mhost1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false
}
```

### ========== tasks ==========

--- using the root user

#### 1. Create ansible.cfg:
  - Must be in "tasks" dir, inside ~ansible
  - Roles path should be ~ansible/tasks/roles and default path should also be considered
  - Inventory file should be ~ansible/tasks/mnodes
  - Remote port 22 for SSH connection
  - User ansible should be used to connect to remote hosts
  - Privilege escalation must be disabled
  - Default module must be "command"
  - Ansible should start 5 forks

Solution: [ansible.cfg](ansible.cfg)

Test (check the 'config file' line):
```bash
$ ansible --version
```

#### 2. Create mnodes inventory file as follows:
  - mhost1 must be part of the host group prod1
  - mhost2 must be part of the host group prod2
  - mhost3 and mhost4 must be part of webservers group
  - prod1 and prod2 must be part of prod group
  - group linux should include all managed hosts

Solution: [mnodes](mnodes)

Test:
```bash
$ ansible --list prod
$ ansible --list webservers
$ ansible --list linux
$ ansible --list all
$ ansible -u root -k -m ping all -o
```

#### - Tasks using only ad-hoc commands

#### 3. Configure mhost4 to listen on non-default ssh port 555
  - ansible should connect to the other hosts on port 22
  - update the inventory file to tell ansible to use port 555 to mhost4

Solution:
```bash
$ ansible -u root -k mhost4 -m lineinfile -a "path=/etc/ssh/sshd_config regexp='^#Port 22' line='Port 555'" 
$ ansible -u root -k mhost4 -m firewalld -a "port=555/tcp permanent=true immediate=true state=enabled"
$ ansible -u root -k mhost4 -m seport -a "ports=555 proto=tcp setype=ssh_port_t state=present"
```

Change the inventory file adding on the end of the mhost4 line 'ansible_port=555'

Test:
```bash
$ ansible -u root -k -m ping all -o
```

Usefull commands that can be used to troubleshoot:
```bash
firewall-cmd --list-ports
semanage port -l
semanage port -a -t ssh_port_t -p tcp 555
semanage port -d -p tcp 555
```

#### 4. Create ansible user and distribute ssh key using ad-hoc commands
  - use ad-hoc command to create user ansible on all managed nodes (password '123')
  - create a key pair (if you don't already have one)
```bash
ssh-keygen -t rsa
```
  - copy the pub key to the managed nodes
  - add user to sudoers file, allowing privilege escalation

Solution:
```bash
$ ansible -u root -k all -m user -a "name=ansible password='{{'123' | password_hash('sha512')}}'"
$ ansible -u root -k all -m authorized_key -a "user=ansible state=present key='{{ lookup('file', '/home/ansible/.ssh/id_rsa.pub') }}'"
```
OBS.: Another option to copy the key would be to use the 'copy' module
```bash
$ ansible -u root -k all -m lineinfile -a "path=/etc/sudoers insertbefore='## Read drop-in' line='ansible ALL=(ALL) NOPASSWD: ALL'"
```

Test:
```bash
$ ansible -m ping all -o
```

--- from this point onwards, use 'ansible' user

#### 5. Configuring MOTD with ad-hoc commands
Add the text:
Ansible managed host

Solution:
a. Using the lineinfile module
```bash
$ ansible -b -m lineinfile -a "path=/etc/motd line='Ansible managed host'"
```

b. Using the copy module
```bash
$ ansible -b -m copy -a "dest=/etc/motd content='Ansible managed host'"
```

#### 6. Configure managed hosts to use BaseOS and AppStream yum repos with ad-hoc commands (disable gpg check)
  - Pre task: mount or copy cdrom contents to /srv.
  - Repo 1: name "BaseOS", description "DNF BaseOS Repo", baseurl=file:///srv/BaseOS, gpgcheck "1", gpgkey "/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial", enabled "1"
  - Repo 2: name "AppStream", description "DNF AppStream Repo", baseurl "file:///srv/AppStream", gpgcheck "1", gpgkey "/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial", enabled "1"

Solution:
```bash
$ ansible all -b -m mount -a "path=/srv src=/dev/cdrom fstype=iso9660 state=mounted"
$ ansible all -b -m yum_repository -a "name='BaseOS' description='DNF BaseOS repo' baseurl='file:///srv/BaseOS' gpgcheck='1' gpgkey='/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial' enabled='1'"
$ ansible all -b -m yum_repository -a "name='AppStream' description='DNF AppStream repo' baseurl='file:///srv/AppStream' gpgcheck='1' gpgkey='/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial' enabled='1'"
```

#### - Tasks using playbooks and ad-hoc commands

#### 7. Create a playbook name 'services.yaml' to:
  - Install, start and enable httpd on webservers;
  - Install, start and enable mariadb on prod;

Solution: [services.yaml](playbooks/services.yaml)
```bash
$ ansible-playbook playbooks/services.yaml --syntax-check
$ ansible-playbook playbooks/services.yaml
```

Test: As we didn't allow inbout http traffic yet, tests should be executed from within each host.

a. testing webservers
```bash
$ ansible webservers -m uri -a "url=http://localhost"
$ ansible -b webservers m shell -a 'ss -natp | grep *:80'
```

b. testing db servers
```bash
$ ansible -b prod m shell -a 'ss -natp | grep *:3306'
$ ansible prod -o -m mysql_info -a "login_user=root filter=version"
```
OBS.: to use the mysql_info module, you must have PyMySQL installed on the nodes

#### 8. Create a user on all managed nodes via playbook (mark_user.yaml)
  - Username 'mark', password 'password', sha512

Solution: [mark_user.yaml](playbooks/mark_user.yaml)
```bash
$ ansible-playbook playbooks/mark_user.yaml --syntax-check
$ ansible-playbook playbooks/mark_user.yaml
```

#### 9. Create the 'mark_file.yaml' playbook that will create the '/root/mark_file' in all managed nodes
  - User and group should be set to mark
  - User rwx, group rw, others no permission
  - Set gid bit

Solution: [mark_file.yaml](playbooks/mark_file.yaml)
```bash
$ ansible-playbook playbooks/mark_file.yaml --syntax-check
$ ansible-playbook playbooks/mark_file.yaml
```

Tests:
```bash
$ ansible -b all -a 'ls -l /root/mark_file'
```

#### 10. Create the '/root/file1.txt' file with ad-hoc command on all managed nodes
  - Content of the file: 'This file was created with Ansible'
  - Remove all permissions for others on the file

Solution:
```bash
$ ansible -b -m copy -a "dest=/root/file1.txt content='This file was created with Ansible' mode=o-rwx" all
```

Tests:
```bash
$ ansible -b -a "ls -l /root/file1.txt"
$ ansible -b -a "cat /root/file1.txt"
```

#### 11. Create the 'archive.yaml' playbook to:
  - Execute playbook on webservers
  - Archive the contents of /etc in /root/etc-<hostname>.tar.bz2 you may use ansible_facts or magic variables (I'm the second option)
  - Compress with bzip2
  - Copy the files to the local /tmp directory on the ansible controler

Solution: [archive.yaml](playbooks/archive.yaml)
```bash
$ ansible-playbook playbooks/archive.yaml --syntax-check
$ ansible-playbook playbooks/archive.yaml
```

Tests:
On the local machine (ansible controler node), execute:
```bash
ls -l /tmp/*etc.tar.bz2
```

#### 12. Create the 'cronjobs.yaml' playbook to schedule the below tasks:
  - Restart rsyslog service at 23h and 6h on prod nodes every day
  - Restart rsyslog service at 2h on webservers on every monday

Solution: [cronjobs.yaml](playbooks/cronjobs.yaml)
```bash
$ ansible-playbook playbooks/cronjobs.yaml --syntax-check
$ ansible-playbook playbooks/cronjobs.yaml
```

Alternative solution using magic variables with conditionals: playbooks/cronjobs_magicvars.yaml

Tests:
```bash
$ ansible -b all -a 'crontab -l'
```

#### 13. Create the 'update_prod1.yaml' playbook to update all packages on prod1 node

Solution: [update_prod1.yaml](playbooks/update_prod1.yaml)
```bash
$ ansible-playbook playbooks/update_prod1.yaml --syntax-check
$ ansible-playbook playbooks/update_prod1.yaml
```

Tests:
```bash
$ ansible -b all -a 'crontab -l'
```

#### 14. Create the 'http_configs.yaml' playbook to:
  - Change the httpd DocumentRoot directory from /var/www/html to /var/web/html
  - Set it's selinux context type to 'httpd_sys_content_t' (use the sefcontext module, making it persistent - 'ansible-doc sefcontext' for help)
  - Create a custom index.html file at new location
  - Allow inbound traffic for http
  - Setting should be persistent
  - Reload both services by making usage of handlers
  - Playbook should be executed on webservers only

Solution: [httpd_configs.yaml](playbooks/httpd_configs.yaml)
```bash
$ ansible-playbook playbooks/httpd_configs.yaml --syntax-check
$ ansible-playbook playbooks/httpd_configs.yaml 
```

Tests:
```bash
curl http://mhost3
curl http://mhost3
$ ansible webservers -b -a 'ls -lZd /var/web'
```

#### 15. Create the 'create_testing_networks_groups.yaml' playbook to perform the below tasks:
  - Create group 'testing' on webservers, gid=3030
  - Create group 'networks' on prod nodes, gid=4040
  - Use magic variables to diferentiate between the groups

Solution: [create_testing_networks_groups.yaml](playbooks/create_testing_networks_groups.yaml)
```bash
$ ansible-playbook playbooks/create_testing_networks_groups.yaml --syntax-check
$ ansible-playbook playbooks/create_testing_networks_groups.yaml 
```

Tests:
```bash
$ ansible prod -a 'grep ^networks\: /etc/group'
$ ansible webservers -a 'grep ^testing\: /etc/group'
```

#### 16. Create the 'parted.yaml' playbook to:
  - Create an extended partition on all managed nodes
  - Use all remaining space for extended partition
  - Create one logical partition of size 200 MB on all managed nodes

Solution: [parted.yaml](playbooks/parted.yaml)
```bash
$ ansible-playbook playbooks/parted.yaml --syntax-check
$ ansible-playbook playbooks/parted.yaml
```

Tests:
```bash
$ ansible -b -m shell -a 'dumpe2fs /dev/sda5 | head -1 || echo "invalid fs"' all
$ ansible -b -m parted -a 'device=/dev/sda5 unit=MiB' all
```
#### 17. Create the 'mount.yaml' playbook to:
  - Format the '/dev/sda5' device with 'ext4' fs
  - Create /opt/tmp
  - Mount the fs in /opt/tmp
  - Make sure to add entry to fstab

Solution: [mount.yaml](playbooks/mount.yaml)
```bash
$ ansible-playbook playbooks/mount.yaml --syntax-check
$ ansible-playbook playbooks/mount.yaml
```

Tests:
```bash
$ ansible all -a 'grep /opt/tmp /etc/fstab'
$ ansible all -a 'df /opt/tmp'
```

#### 18. Create the 'file.sh' shell script to execute the following tasks using ad-hoc commands:
  - Create the '/root/redhat/ex294/results' file on prod nodes
  - Give full permissions to group and read/execution to others
  - Set mark as owner and group
  - Create a symbolic link in /root with the default name

Solution: [file.sh](scripts/file.sh)
```bash
$ bash scripts/file.sh
```

Tests:
```bash
$ ansible prod -b -a 'find /root -name results -ls'
```

#### 19. Create the 'user.sh' shell script to execute the following tasks using ad-hoc commands:
  - Create user 'rhce' on all nodes:
    - Password should be: 'rhce_pass' using sha512 to generate the password hash
    - UID: 2021
  - Create the 'ex294' group, which should be a secondary group for the same user

Solution: [user.sh](scripts/user.sh)
```bash
$ bash scripts/user.sh
```

Tests:
```bash
$ ansible all -k -u rhce -m ping
$ ansible all -k -u rhce -a 'id'
```

#### 20. Create the 'motd_with_condition.yaml' playbook to configure motd on:
  - webservers with "This is a webserver node\n"
  - prod1 with "This is a prod1 node\n"
  - Set "hosts: all" in the play book as the selection must be made based on contitions.

Solution: [motd_with_conditionals.yaml](playbooks/motd_with_conditionals.yaml)

```bash
$ ansible-playbook playbooks/motd_with_conditionals.yaml --syntax-check
$ ansible-playbook playbooks/motd_with_conditionals.yaml
```

Tests:
```bash
$ ansible all -a "grep 'This is a' /etc/motd"
```

#### 21. Create the 'packages.yaml' playbook to install:
  - httpd-manual on webservers
  - mariadb-test on prod nodes
  - Set "hosts: all" in the play book as the selection should be made based on contitions.

Solution: [packages_with_conditionals.yaml](playbooks/packages_with_conditionals.yaml)

```bash
$ ansible-playbook playbooks/packages_with_conditionals.yaml --syntax-check
$ ansible-playbook playbooks/packages_with_conditionals.yaml
```

Tests:
```bash
$ ansible all -a 'rpm -q mariadb-test'
$ ansible all -a 'rpm -q httpd-manual'
```

#### 22. Create the 'firewall_config.yaml'playbook to:
  - Configure webservers to accept https and ntp inbound traffic
  - Configure prod nodes to accept traffic on port range 400-404/tcp and 3306/tcp
  - Firewall rules should be persistent and service must be reloaded (don't use the immediate option on firewalld module).
  - Set "hosts: all" in the play book as the selection should be made based on contitions.

Solution: [firewall_config.yaml](playbooks/firewall_config.yaml)

```bash
$ ansible-playbook playbooks/firewall_config.yaml --syntax-check
$ ansible-playbook playbooks/firewall_config.yaml
```

Tests:
```bash
$ ansible prod -b -a 'firewall-cmd --list-port'
$ ansible webservers -b -a 'firewall-cmd --list-service'
```

#### 23. Create the 'create_users.yaml' playbook to create users, based on:
  - 'userdetails.yaml' should contain user information
    - username, department, age (below)
```yaml
---
users:
  - username: lisa
    department: software developer
    age: 32
  - username: bob
    department: testing
    age: 38
  - username: lara
    department: hr
    age: 28
...
```
  - 'passwords.yaml' should contain the user passwords (format, user_password: passwords)
```yaml
---
all_users_pass: wadda
...
```
  - Create users:
    - webservers when user's department is 'software developer', and assign 'testing' group as suplementary to it.
    - prod nodes when user's department is 'testing' and assign 'network' group as suplementary to it.
    - all managed nodes when user's department is HR.
    - The password should be the one defined on 'password.yaml' adding '_username' to it (wadda_lara, to user lara for example)

Solution: [create_users.yaml](playbooks/create_users.yaml)

```bash
$ ansible-playbook playbooks/create_users.yaml --syntax-check
$ ansible-playbook playbooks/create_users.yaml
```

Tests: try to login to the nodes using the created users accordingly

#### 24. Create the 'vgroup.yaml' playbook to:
  - Install lvm2 package on all nodes
  - Create a logical partition of size 1GiB on webservers
  - Create a logical partition of size 600MiB on prod1 nodes
  - Create a volume group with name 'vgroup' using the mentioned partitions

#### 25. Create the 'logvol.yaml' playbook to:
  - Create logical volume of size 800MiB if vgroup has enough free space (> 800MiB)
  - Create logical volume of size 500MiB if vgroup has less than 800MiB
  - The name of the logical volume should be 'lvm'
  - Message 'vol group does not exist' should be displayed if vgroup wasn't created on node
  - Use 'lvs' with ansible ad-hoc commands to verify.

#### 26. Create the 'volume.yaml' playbook to:
  - Create a logical volume with name 'vol' on managed nodes, using the remaining space on vgroup
  - Display 'vgroup does not exist' in case the vg wasn't created on a given node

#### 27. Create the 'mount_vol.yaml' playbook to:
  - Create a xfs filesystem on lv 'vol'.
  - Mount it on '/volume/lvm' (create the mount point as well), in a persistent way.

lvscan
vgscan
vgdisplay
