# Playbooks
This repository includes all the playbooks needed to prepare a server to run [TimeOverflow](https://github.com/coopdevs/timeoverflow).
```
playbooks/
├── provision.yml
└── sys_admins.yml
```

## sys_admins.yml
This playbook will prepare the host to allow access to all the system administrators.

The first time you run it against a brand new host you need to run it as `root` user.
You'll also need passwordless SSH access to the `root` user.
```
ansible-playbook playbooks/sys_admins.yml --limit=dev -u root
```

All the others times, the script will asssume that your user is included in the system administrators list for the given host.

For example in the case of `development` environment the script will assume that the user that is running it is included in the system administrators [list](https://github.com/coopdevs/timeoverflow-provisioning/blob/master/inventory/host_vars/local.timeoverflow.org/config.yml#L5) for that environment.

To run the playbook as a system administrator just use the following command:
```
ansible-playbook playbooks/sys_admins.yml --limit=dev
```
Ansible will try to connect to the host using the system user.

## provision.yml
This playbook will set up a server with all the operational dependencies.

To run it use the following command:
```
ansible-playbook playbooks/provision.yml --limit=dev
```
