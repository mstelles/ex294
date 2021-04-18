## Scripts
###
### General scripts
The below scripts are attempts to make the life easier, by automatically configuring VMs or deploying docker containers. It might be useful but it's not what I used to study for the certification.
- prepare_docker.sh: purges and re-deploys 'n' containers to apply configs with user "ansible", pass "123"
- prepare_docker.py: some day will do the same as above
- prepare_vmware.sh: pre-configures vmware hosts, which should already have the "ansible" user configured with sudo access enabled
  - ssh-copy-id
  - network config
  - disable selinux
  - minor shell env settings
  - tests hosts by gathering ansible facts
