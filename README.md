# Simple Phoenix deployment with Ansible

By "simple" I mean the following:

- A single server
- No containers
- Mix releases built locally
- Postgres on the same server
- Some downtime during deployment is acceptable

## Getting started

Make sure Ansible is installed and that you have SSH access to the target server.

### Add host

Specify the target host by updating the `hosts` file.

```ini
[hosts]
123.123.123.123
```

### Update vars file

Modify the `group_vars/hosts/vars` file to reflect your environment's specific details.

```yaml
user: david
port: 4000
project_name: my_app
# etc...
```

### Create a vault

Ansible Vault is used to encrypt sensitive data, such as database credentials and secret keys. To create a new vault:

```bash
ansible-vault create group_vars/hosts/vault
```

To avoid entering the vault password for each task, store it in a file:

```bash
echo 'my_vault_password' > .vault_pass
```

This file is not tracked by version control.

The vault can be edited by running:

```bash
ansible-vault edit group_vars/hosts/vault
```

Your vault should contain the following secrets:

```yaml
vault_db_user: secret
vault_db_password: secret
vault_secret_key_base: secret
```

## Playbooks

### Create user

Creates the user defined in `group_vars/hosts/vars` and disables SSH root access. It can/should be executed once.

```
ansible-playbook 01-create-user.yml
```

### Configure server

Once the user is created, configure the server by running:

```
ansible-playbook 02-configure-server.yml
```

This playbook performs the following actions:

- Installs updates and applies [basic security configurations](https://www.redhat.com/sysadmin/ansible-linux-server-security)
- Installs and configures Postgres, and sets up the necessary database and privileges
- Sets up Caddy for handling requests

### Deploy application

With the server configured, deploy the Phoenix application using:

```
ansible-playbook 03-deploy-application.yml
```

This playbook builds a Mix release locally and transfers the resulting tarball to the server. It also applies any changes to the Caddyfile and service unit file. Note: Expect approximately 5-10 seconds of downtime during deployment. During this period, Caddy will serve a basic HTML maintenance page.

---

**Todo**

- [ ] Rollback app version using tarballs on server
