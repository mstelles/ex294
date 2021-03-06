## Personal stuff created to prepare to my [EX294](https://www.redhat.com/en/services/training/ex294-red-hat-certified-engineer-rhce-exam-red-hat-enterprise-linux-8)  exam.

## Disclaimer:
- The tasks described below are on the same level of what you would find on the certification exam. Although I executed 95% of the test without problems and testing the applied configs, I didn't pass the exam and the only report received by them was:

        OBJECTIVE: SCORE
        Understand core components of Ansible: 59%
        Install and configure Ansible: 100%
        Run ad-hoc Ansible commands: 0%
        Use Ansible modules for system administration tasks: 56%
        Create Ansible plays and playbooks: 67%
        Create and use templates to create customized configuration files: 100%
        Work with Ansible variables and facts: 100%
        Create and work with roles: 67%
        Download and use roles with Ansible Galaxy: 0%
        Use Ansible Vault in playbooks to protect sensitive data: 43%

Not sure why but well, that's how they do things.

Feel free to use if you like but don't take this as a course for the certification. Probably what they want is to sell their 2k USD prep course, where they might give the "correct" answers for the test.

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
  - Playbooks: ```~ansible/tasks/playbooks```
    - Every command should br executed from ```~ansible/tasks``` directory.
  - Scripts: ```~ansible/tasks/scripts```
  - Roles: ```~ansible/tasks/roles```

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

#### 1. Create ```ansible.cfg```.
  - Must be in ```tasks``` dir, inside ```~ansible```.
  - Roles path should be ```~ansible/tasks/roles``` and default path should also be considered.
  - Inventory file should be ```~ansible/tasks/mnodes```.
  - Remote port 22 for SSH connection.
  - User ansible should be used to connect to remote hosts.
  - Privilege escalation must be disabled.
  - Default module must be "command".
  - Ansible should start 5 forks.

Solution: [ansible.cfg](ansible.cfg)

Test (check the 'config file' line):
```bash
$ ansible --version
```

#### 2. Create mnodes inventory file as follows:
  - mhost1 must be part of the host group prod1.
  - mhost2 must be part of the host group prod2.
  - mhost3 and mhost4 must be part of webservers group.
  - prod1 and prod2 must be part of prod group.
  - group linux should include all managed hosts.

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

--- using the root user (-u root on ansible ad-hoc commands)

#### 3. Configure mhost4 to listen on non-default ssh port 555
  - ansible should connect to the other hosts on port 22.
  - update the inventory file to tell ansible to use port 555 to mhost4.

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
  - use ad-hoc command to create user ansible on all managed nodes (password '123').
  - create a key pair (if you don't already have one).
```bash
ssh-keygen -t rsa
```
  - copy the pub key to the managed nodes.
  - add user to sudoers file, allowing privilege escalation.

Solution:
```bash
$ ansible -u root -k all -m user -a "name=ansible password='{{'123' | password_hash('sha512')}}'"
$ ansible -u root -k all -m authorized_key -a "user=ansible state=present key='{{ lookup('file', '/home/ansible/.ssh/id_rsa.pub') }}'"
```
OBS.: Another option to copy the key would be to use the 'copy' module
```bash
$ ansible -u root -k all -m copy -a "dest=/home/ansible/.ssh/id_rsa.pub src=/home/ansible/.ssh/id_rsa.pub mode='0400'"
```

Test:
```bash
$ ansible -m ping all -o
```

--- from this point onwards, use 'ansible' user

#### 5. Configuring MOTD with ad-hoc commands
Add the text: 'Ansible managed host'.

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
  - Repo 1: name "BaseOS", description "DNF BaseOS Repo", baseurl=file:///srv/BaseOS, gpgcheck "1", gpgkey "/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial", enabled "1".
  - Repo 2: name "AppStream", description "DNF AppStream Repo", baseurl "file:///srv/AppStream", gpgcheck "1", gpgkey "/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial", enabled "1".

Solution:
```bash
$ ansible all -b -m mount -a "path=/srv src=/dev/cdrom fstype=iso9660 state=mounted"
$ ansible all -b -m yum_repository -a "name='BaseOS' description='DNF BaseOS repo' baseurl='file:///srv/BaseOS' gpgcheck='1' gpgkey='/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial' enabled='1'"
$ ansible all -b -m yum_repository -a "name='AppStream' description='DNF AppStream repo' baseurl='file:///srv/AppStream' gpgcheck='1' gpgkey='/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial' enabled='1'"
```

#### - Tasks using playbooks and ad-hoc commands

#### 7. Create the ```services.yaml``` playbook to:
  - Install, start and enable httpd on webservers.
  - Install, start and enable mariadb on prod.

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

#### 8. Create the ```user01_user.yaml``` playbook to add the correspondent user to all managed nodes.
  - Username 'user01', password 'password', sha512 as hash algorithm.

Solution: [user01_user.yaml](playbooks/user01_user.yaml)
```bash
$ ansible-playbook playbooks/user01_user.yaml --syntax-check
$ ansible-playbook playbooks/user01_user.yaml
```

#### 9. Create the ```user01_file.yaml``` playbook that will create the ```/root/user01_file``` in all managed nodes
  - User and group should be set to user01.
  - User rwx, group rw, others no permission.
  - Set gid bit.

Solution: [user01_file.yaml](playbooks/user01_file.yaml)
```bash
$ ansible-playbook playbooks/user01_file.yaml --syntax-check
$ ansible-playbook playbooks/user01_file.yaml
```

Tests:
```bash
$ ansible -b all -a 'ls -l /root/user01_file'
```

#### 10. Create the ```/root/file1.txt``` file with ad-hoc command on all managed nodes
  - Content of the file: 'This file was created with Ansible'.
  - Remove all permissions for others on the file.

Solution:
```bash
$ ansible -b -m copy -a "dest=/root/file1.txt content='This file was created with Ansible' mode=o-rwx" all
```

Tests:
```bash
$ ansible -b -a "ls -l /root/file1.txt"
$ ansible -b -a "cat /root/file1.txt"
```

#### 11. Create the ```archive.yaml``` playbook to:
  - Execute playbook on webservers.
  - Archive the contents of ```/etc``` in ```/root/etc-<hostname>.tar.bz2``` you may use ansible_facts or magic variables (I'm using the second option).
  - Compress with bzip2.
  - Copy the files to the local ```/tmp``` directory on the ansible controler.

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

#### 12. Create the ```cronjobs.yaml``` playbook to schedule the below tasks:
  - Restart rsyslog service at 23h and 6h on prod nodes every day.
  - Restart rsyslog service at 2h on webservers on every monday.

Solution: [cronjobs.yaml](playbooks/cronjobs.yaml)
```bash
$ ansible-playbook playbooks/cronjobs.yaml --syntax-check
$ ansible-playbook playbooks/cronjobs.yaml
```

Alternative solution using magic variables with conditionals: [cronjobs_magicvars](playbooks/cronjobs_magicvars.yaml)

Tests:
```bash
$ ansible -b all -a 'crontab -l'
```

#### 13. Create the ```update_prod1.yaml``` playbook to update all packages on prod1 node

Solution: [update_prod1.yaml](playbooks/update_prod1.yaml)
```bash
$ ansible-playbook playbooks/update_prod1.yaml --syntax-check
$ ansible-playbook playbooks/update_prod1.yaml
```

#### 14. Create the ```httpd_configs.yaml``` playbook to:
  - Change the httpd DocumentRoot directory from ```/var/www/html``` to ```/var/web/html```.
  - Set it's selinux context type to 'httpd_sys_content_t' (use the sefcontext module, making it persistent - 'ansible-doc sefcontext' for help).
  - Create a custom ```index.html``` file at new location.
  - Allow inbound traffic for http protocol.
  - Setting should be persistent.
  - Reload both services by making usage of handlers.
  - Playbook should be executed on webservers only.

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

#### 15. Create the ```create_testing_networks_groups.yaml``` playbook to perform the below tasks:
  - Create group 'testing' on webservers, gid=3030.
  - Create group 'networks' on prod nodes, gid=4040.
  - Use magic variables to diferentiate between the groups.

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

#### 16. Create the ```parted.yaml``` playbook to:
  - Create an extended partition on all managed nodes.
  - Use all remaining space for extended partition.
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
#### 17. Create the ```mount.yaml``` playbook to:
  - Format the ```/dev/sda5``` device with 'ext4' filesystem.
  - Create ```/opt/tmp```.
  - Mount the fs in ```/opt/tmp```.
  - Make sure to add entry to fstab.

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

#### 18. Create the ```file.sh``` shell script to execute the following tasks using ad-hoc commands:
  - Create the ```/root/redhat/ex294/results``` file on prod nodes.
  - Give full permissions to group and read/execution to others.
  - Set mark as owner and group.
  - Create a symbolic link in ```/root``` with the default name.

Solution: [file.sh](scripts/file.sh)
```bash
$ bash scripts/file.sh
```

Tests:
```bash
$ ansible prod -b -a 'find /root -name results -ls'
```

#### 19. Create the ```user.sh``` shell script to execute the following tasks using ad-hoc commands:
  - Create the 'ex294' group.
  - Create user 'rhce' on all nodes:
    - Password should be: 'rhce_pass' using sha512 to generate the password hash.
    - UID: 2021.
    - 'ex294' group as secondary.

Solution: [user.sh](scripts/user.sh)
```bash
$ bash scripts/user.sh
```

Tests:
```bash
$ ansible all -k -u rhce -m ping
$ ansible all -k -u rhce -a 'id'
```

#### 20. Create the ```motd_with_condition.yaml``` playbook to configure motd on:
  - Set "hosts: all" in the playbook as the selection must be made based on contitions.
  - webservers with "This is a webserver node\n".
  - prod1 with "This is a prod1 node\n".

Solution: [motd_with_conditionals.yaml](playbooks/motd_with_conditionals.yaml)

```bash
$ ansible-playbook playbooks/motd_with_conditionals.yaml --syntax-check
$ ansible-playbook playbooks/motd_with_conditionals.yaml
```

Tests:
```bash
$ ansible all -a "grep 'This is a' /etc/motd"
```

#### 21. Create the ```packages.yaml``` playbook to install:
  - Set "hosts: all" in the playbook as the selection should be made based on contitions.
  - httpd-manual on webservers.
  - mariadb-test on prod nodes.

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

#### 22. Create the ```firewall_config.yaml``` playbook to:
  - Set "hosts: all" in the playbook as the selection should be made based on contitions.
  - Configure webservers to accept https and ntp inbound traffic.
  - Configure prod nodes to accept traffic on port range 400-404/tcp and 3306/tcp.
  - Firewall rules should be persistent and service must be reloaded (don't use the immediate option on firewalld module).

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

#### 23. Create the ```create_users.yaml``` playbook to create users, based on:
  - 'userdetails.yaml' should contain user information.
    - username, department, age (below).

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
  - 'passwords.yaml' should contain the user passwords (format, user_password: passwords).

```yaml
---
all_users_pass: wadda
...
```
  - Create users:
    - webservers when user's department is 'software developer', and assign 'testing' group as suplementary to it.
    - prod nodes when user's department is 'testing' and assign 'network' group as suplementary to it.
    - all managed nodes when user's department is HR.
    - The password should be the one defined on ```password.yaml``` adding '_username' to it (wadda_lara, to user lara for example).

Solution: [create_users.yaml](playbooks/create_users.yaml)

```bash
$ ansible-playbook playbooks/create_users.yaml --syntax-check
$ ansible-playbook playbooks/create_users.yaml
```

Tests: try to login to the nodes using the created users accordingly

#### 24. Create the ```vgroup.yaml``` playbook to:
  - Install lvm2 package on all nodes.
  - webservers: Create a 1GiB logical partition.
  - prod1 nodes: create a 600MiB logical partition.
  - On webservers and prod1 nodes, create the 'vgroup' volume group with using the newly created partition.
  - Use conditionals to select the appropriate nodes.

Solution: [vgroup.yaml](playbooks/vgroup.yaml)

```bash
$ ansible-playbook playbooks/vgroup.yaml --syntax-check
$ ansible-playbook playbooks/vgroup.yaml
```

Tests: 
```bash
$ ansible -b -m shell -a 'fdisk -l /dev/sda | tail -1'
$ ansible -b -a 'vgscan' all
$ ansible -b -a 'vgdisplay' all
```

#### 25. Create the ```logvol.yaml``` playbook to:
  - Create logical volume of size 800MiB if vgroup has enough free space (> 800MiB).
  - Create logical volume of size 500MiB if vgroup has less than 800MiB.
  - The name of the logical volume should be 'lvm'.
  - Message 'vol group does not exist' should be displayed if vgroup wasn't created on node.
  - Use 'lvs' with ansible ad-hoc commands to verify.

Solution: [logvol.yaml](playbooks/logvol.yaml)

```bash
$ ansible-playbook playbooks/logvol.yaml --syntax-check
$ ansible-playbook playbooks/logvol.yaml
```

Tests: 
```bash
$ ansible -b -a 'lvscan' all
```

#### 26. Create the ```volume.yaml``` playbook to:
  - Create a logical volume with name 'vol' on managed nodes, using the remaining space on vgroup.
  - Display 'vgroup does not exist' in case the vg wasn't created on a given node.

Solution: [volume.yaml](playbooks/volume.yaml)

```bash
$ ansible-playbook playbooks/volume.yaml --syntax-check
$ ansible-playbook playbooks/volume.yaml
```

Tests: 
```bash
$ ansible -b -a 'lvscan' all
```

#### 27. Create the ```mount_vol.yaml``` playbook to:
  - Create the '/volume/lvm' directory to serve as mount point.
  - Create a xfs filesystem on lv 'vol'.
  - Mount it on '/volume/lvm', in a persistent way.

Solution: [mount_vol.yaml](playbooks/mount_vol.yaml)

```bash
$ ansible-playbook playbooks/mount_vol.yaml --syntax-check
$ ansible-playbook playbooks/mount_vol.yaml
```

Tests: 
```bash
$ ansible -a 'df /volume/lvm' all
```

#### - Some jinja2 theory


### 28. Jinja2 if example.

  - Create the ```j2if.yaml``` playbook with if, elif, else conditions to validade hosts in groups.
  - Do not enclose variables on quotation marks, only the strings.

Solution: [j2if.yaml](playbooks/j2if.yaml)

```bash
$ ansible-playbook playbooks/j2if.yaml --syntax-check
$ ansible-playbook playbooks/j2if.yaml
```

### 29. Jinja2 for example.

  - Create the ```j2for.yaml``` playbook to iterate over the hosts from the play.

Solution: [j2for.yaml](playbooks/j2for.yaml)

```bash
$ ansible-playbook playbooks/j2for.yaml --syntax-check
$ ansible-playbook playbooks/j2for.yaml
```

### 30. Create the ```host_list.yaml``` playbook to:
  - Set "hosts: all" in the playbook as the selection should be made based on conditions.
  - Create the ```/root/host_list.txt``` file on prod1 nodes with a list of all managed hosts.
  - The playbook should use the ```host_list.j2``` template to generate this list.

Solution: 
  [host_list.yaml](playbooks/host_list.yaml)
  [host_list.j2](templates/host_list.j2)

```bash
$ ansible-playbook playbooks/host_list.yaml --syntax-check
$ ansible-playbook playbooks/host_list.yaml
```

Tests:
```bash
$ ansible -b -a 'cat /root/host_list.txt' prod1
```

### 31. Create the ```partition_size_report.yaml``` playbook to:
  - Set "hosts: all" in the playbook as the selection should be made based on contitions.
  - Collect partition size information and add it to the ```/root/partition_size_report.txt``` file on prod2 nodes.
  - Each line should show the hostname to identify the host which the partition belongs.
  - The playbook should use the ```partiton_size_report.j2``` template to get disk information.

Solution: 
  [partition_size_report.yaml](playbooks/partition_size_report.yaml)
  [partition_size_report.j2](templates/partition_size_report.j2)

```bash
$ ansible-playbook playbooks/partition_size_report.yaml --syntax-check
$ ansible-playbook playbooks/partition_size_report.yaml
```

Tests:
```bash
$ ansible -b -a 'cat /root/partition_size_report.txt' prod2
```

### 32. Create the ```etc_hosts.yaml``` playbook to:
  - Execute on all managed nodes.
  - Create appropriate entries for the hosts on ```/etc/hosts``` file.
  - The playbook should use the ```etc_hosts.j2``` template.
    - Use a for statement to loop through the hosts.
    - Use a if statement to check if the interface is present on the managed nodes.

Solution: 
  [etc_hosts.yaml](playbooks/etc_hosts.yaml)
  [etc_hosts.j2](templates/etc_hosts.j2)

```bash
$ ansible-playbook playbooks/etc_hosts.yaml --syntax-check
$ ansible-playbook playbooks/etc_hosts.yaml
```

Tests:
```bash
$ ansible -b -a 'cat /etc/hosts' all
```

### 33. Create the ```sysinfo.yaml``` template to:
  - Collect below details from managed nodes:
    - hostname.
    - size of vgroup.
    - size of 'lvm' logical volume.
    - Ansible OS family.
  - Store the information on each remote node, in the ```/root/sysinfo-<hostname>.txt``` file.
  - Use the ```sysinfo.j2``` template to gather the requested details.

Solution: 
  [sysinfo.yaml](playbooks/sysinfo.yaml)
  [sysinfo.j2](templates/sysinfo.j2)

```bash
$ ansible-playbook playbooks/sysinfo.yaml --syntax-check
$ ansible-playbook playbooks/sysinfo.yaml
```

Tests:
```bash
$ ansible -b -m shell -a 'cat /etc/sysinfo*' all
```

#### - Ansible vault theory

##### Encrypt a variable and get it's value while executing the playbook

  - Create the encrypted value for the variable.
```bash
$ ansible-vault encrypt_string --name '<var name>' '<password>' --ask-vault-pass
```
  - Copy the variable with the value. Ex.:
```bash
password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          32623463386364616635363132366566666235646565306633306432616434366162626464303866
          3731666561303763663362313933336631303930303162650a303661323665336638636131316135
          33383261653532653462376232646162343265383434626166383966303162626337626634346137
          3866643431303363310a353733316632666630343838333763353965666362613866643135376333
          3836
```
  - Create the ```vault_encrypt_var.yaml``` playbook, adding the variable with the encrypted value generated on the last step.
  - Run the playbook providing the vault password used to generate the encrypted value for the variable.
```bash
$ ansible-playbook playbooks/vault_encrypt_var.yaml --ask-vault-pass
```

##### Encrypt a playbook and a variable inside the same playbook

  - Encrypt the variable, adding an id to it.
```bash
$ ansible-vault encrypt_string --vault-id '<id name>'@prompt --name '<variable name>' '<password>'
```
  - Encrypt the playbook, ading a different id to it.
```bash
$ ansible-vault encrypt --vault-id '<id name>'@prompt '<playbook or file>'
```

  - Run the playbook:
```bash
$ ansible-playbook <playbook> --vault-id '<first id>'@prompt --vault-id '<second id>'@prompt
```

#### - Ansible roles and ansible-galaxy

- Use the ```ansible-galaxy init <role name>``` command to create a default directory and files structure.

- Downloading roles:
  - ```ansible-galaxy install <user>.<role>```
  - It's also possible to create a requirements file on YAML format to download several roles at once. Ex:

```yaml
- src: http://some/url/here/
  version: master
  name: role_name_in_disk
- src: geerlingguy.apache
  version: master
  name: my_apache_role
- src: geerlingguy.docker
  version: master
```
  - Then execute ```ansible-galaxy install -r <requirements file>.yaml```
  - To list the roles, execute ```ansible-galaxy list```

##### linux system roles
  - Install the rhel-system-roles package.
  - Administrative roles will be placed under ```/usr/share/ansible/roles/``` directory.
  - Example playbooks will be at ``/usr/share/doc/rhel-system-roles/``` directory.
  - Example of roles on this package:
    - network
    - timesync
    - storage
    - selinux

###### Using the ```timesync``` role to sync the nodes via ntp

  - On control node, allow the service to receive requests from the nodes, adjusting ```/etc/chrony.conf``` file, on the below line.
```bash
allow 192.168.1.0/24 
```

  - Check if chronyd is enabled and running. If so, restart it.
```bash 
# systemctl restart chronyd
```

  - Check the execution of the daemon.
```bash
# chronyc sources -v
```

  - Make sure there's a firewall rule allowing the access to this service (port 123/udp) and if not, create the rule.
```bash
# firewall-cmd --list-ports
# firewall-cmd --zone=public --add-port=123/udp --permanent
# firewall-cmd --reload
```

OBS.: Of course all this could be done using ansible ad-hoc commands or even a simple playbook.

  - Check on managed nodes the time and date configuration.
```bash
$ ansible all -a 'timedatectl status'
```

  - 
