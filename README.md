# Playbooks [![Build Status](https://travis-ci.org/coopdevs/timeoverflow-provisioning.svg?branch=master)](https://travis-ci.org/coopdevs/timeoverflow-provisioning)
This repository includes all the playbooks needed to prepare a server to run [TimeOverflow](https://github.com/coopdevs/timeoverflow).
```
playbooks/
├── provision.yml
└── sys_admins.yml
```

## Requirements

* Python 3.8.3
* Pip 19.2.3
* Ansible 2.8

First of all, follow the steps specified in https://github.com/pyenv/pyenv-installer to install Pyenv and Pyenv-Virtualenv. Make sure you follow all the steps including updating your shell rc file.

Now, execute the following commands:

```
$ cd timeoverflow-provisioning
$ pyenv install 3.8.3
$ pyenv virtualenv 3.8.3 timeoverflow
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

## CI/CD Pipeline

Our pipeline is designed as follows

            +------------+
            |Lint        |
            +------------+ master +-------------------+
                           +----> | Staging Provision |
            +------------+ merge  +-------------------+
            |CI Provision|
            +------------+


### CI Provision

To ensure the provisioning works and no regressions are introduced we execute said playbook against a dedicated server from Travis CI.

For this to work, we need to encrypt and store a new private key in Travis while the public one needs to be uploaded to this server running from your local machine first. This is necessary for the `travis` user to log into the machine. https://blog.martignoni.net/2019/03/deploy-your-hugo-site/ is the article that served as inspiration.

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

## Staging Provision

We also configured our pipeline to provision staging when merging into master. This way we skip the manual step and staging will always be in sync with master so we can test things in a production-like environment.

## Database migration

We added support for migrating the database to a new production server by means of a dump and a restore. It's implemented in two different playbooks, backup.yml and restore.yml.

First, run the following command against the server you want to migrate from:

```
$ pyenv exec ansible-playbook playbooks/backup.yml --user timeoverflow --limit <source_server> --vault-password-file=.vault_pass
```

This will store the backup file as something like `playbooks/files/timeoverflow_staging-2019-11-18-15:43:01.dump` in your machine. Then, run the following to restore in another server:

```
$ pyenv exec ansible-playbook playbooks/restore.yml --limit <target_server> -e "backup_file=timeoverflow_staging-2019-11-18-15:37:15.sql.gz" --vault-password-file=.vault_pass
```

Note the `backup_file` you specify must be the basename of the file that the `playbooks/backup.yml` downloaded to your `playbooks/files/` directory. Keep in mind you won't see it if you `git status` since it's ignored by Git.

To migrate the old production database you'll have to specify `source_server` as `old_production`, while `target_server` can be `staging` to test things first and the new production host when ready. Remember to run the restore playbook with a sysadmin user with root privileges because it needs to become the app user in many tasks.
