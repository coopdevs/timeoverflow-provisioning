# Playbooks
This repository includes all the playbooks needed to prepare a server to run [TimeOverflow](https://github.com/coopdevs/timeoverflow).
```
playbooks/
├── provision.yml
└── sys_admins.yml
```

## Requirements

* Python 3.7.4
* Pip 19.2.3
* Ansible 2.8

First of all, follow the steps specified in https://github.com/pyenv/pyenv-installer to install Pyenv and Pyenv-Virtualenv. Make sure you follow all the steps including updating your shell rc file.

Now, execute the following commands:

```
$ cd timeoverflow-provisioning
$ pyenv install 3.7.4
$ pyenv virtualenv 3.7.4 timeoverflow
$ pyenv exec pip install -r requirements.txt
```

Install dependencies:
```
$ pyenv exec ansible-galaxy install -r requirements.yml
```

Supported operating system for host: **Ubuntu 16.04 Xenial (64 bit)**

## sys_admins.yml
This playbook will prepare the host to allow access to all the system administrators.

In each environment (`dev`, `staging`, `production`) we can find the list of users that will be created as system administrators.
We use `host_vars` to declare per environment variables:
```yaml
# inventory/host_vars/<YOUR_HOST>/config.yml

sys_admins:
  - name: pepe
    ssh_key: "../pub_keys/pepe.pub"
    state: present
  - name: paco
    ssh_key: "../pub_keys/paco.pub"
    state: present
```

The first time you run it against a brand new host you need to run it as `root` user.
You'll also need passwordless SSH access to the `root` user.
```
$ ansible-playbook playbooks/sys_admins.yml --limit=<environment_name> -u root
```

For the following executions, the script will asssume that your user is included in the system administrators list for the given host.

For example in the case of `development` environment the script will assume that the user that is running it is included in the system administrators [list](https://github.com/coopdevs/timeoverflow-provisioning/blob/master/inventory/host_vars/local.timeoverflow.org/config.yml#L5) for that environment.

To run the playbook as a system administrator just use the following command:
```
$ ansible-playbook playbooks/sys_admins.yml --limit=dev
```
Ansible will try to connect to the host using the system user. If your user as a system administrator is different than your local system user please run this playbook with the correct user using the `-u` flag.
```
$ ansible-playbook playbooks/sys_admins.yml --limit=dev -u <username>
```

## provision.yml
This playbook will set up a server with all the operational dependencies.

To run it use the following command:
```
ansible-playbook playbooks/provision.yml --limit=dev
```

Add `--ask-vault-pass` to execute the command in `staging` and `production`

## CI

To ensure the provisioning works and no regressions are introduced we execute said playbook against a dedicated server from Travis CI.

For this to work, we need to encrypt and store a new private key to while the public one needs to be uploaded to this server running from your local machine first. This is necessary for the `travis` user to log into the machine. https://blog.martignoni.net/2019/03/deploy-your-hugo-site/ is the article that served as inspiration.

This new key-pair gives granular control over the provisioning from CI. If something bad happens we can create a new one.

To set up you'll have to install the `travis` gem executing `bundle install` and run the following commands:

```sh
$ travis login
$ travis encrypt-file travis --add
$ git add travis.enc
```

Add this point the travis CLI changed the `.travis.yml` to add the steps to decrypt the `travis.enc` file. Stage those changes as well and commit.

Then, you can run `ansible-playbook playbooks/sys_admins.yml --limit=ci_server -u root` from your machine to create the Travis user and upload its public key.

Now it's all setup. If you push, Travis should be able to provision the CI server.
