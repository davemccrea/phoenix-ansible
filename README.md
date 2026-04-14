# Simple Phoenix deployment with Ansible

> [!NOTE]
> Intended for use on Ubuntu.

By "simple" I mean the following:

- A single server
- No containers
- Mix releases built locally
- Postgres on the same server
- Some downtime during deployment is acceptable

## Getting started

Make sure Ansible is installed and that you have SSH access to the target server.

### Prepare your Phoenix project

We want Mix to package the release as as tarball. Modidy `mix.exs`:

```elixir
  def project do
    [
      app: :my_app,
      # ...
      releases: [
        my_app: [
          steps: [:assemble, :tar]
        ]
      ],
    ]
  end
```

If you haven't already done so, generate Phoenix release files:

```bash
mix phx.gen.release
```

### Install requirements

Install requirements needed for running the playbooks:

```bash
ansible-galaxy install -r requirements.yml
```

To upgrade all collections to their latest versions:

```bash
ansible-galaxy collection install -r requirements.yml --upgrade
```

### Add host

Specify the target host by updating the `hosts` file:

```ini
[hosts]
123.123.123.123
```

### Update vars file

Modify the `group_vars/hosts/vars` file to reflect your environment's specific details:

```yaml
user: david
app_port: 4000
project_name: my_app # Should match Phoenix project name
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
vault_release_cookie: secret
vault_tailscale_authkey: secret
```

## Playbooks

### Create user

Creates the user defined in `group_vars/hosts/vars` and disables SSH root access. It can/should be executed once.

```bash
ansible-playbook 01-create-user.yml
```

### Configure server

Once the user is created, configure the server by running:

```bash
ansible-playbook 02-configure-server.yml
```

This playbook performs the following actions:

- Install updates and apply basic security configurations
- Install and configures Postgres, and sets up the necessary database and privileges
- Setup Caddy, my chosen reverse proxy

### Deploy application

With the server configured, deploy the Phoenix application using:

```bash
ansible-playbook 03-deploy-application.yml
```

This playbook builds a Mix release locally and transfers the resulting tarball to the server. It also applies any changes to the Caddyfile and service unit file. Note: Expect approximately 5-10 seconds of downtime during deployment. During this period, Caddy will serve a basic HTML maintenance page.

## Connect with Livebook

Start Livebook on your local machine.

Use "Attached Node" to connect to the Elixir node running on the server. The name of the server is the Tailscale hostname plus the tailnet name, e.g. `my_app@my-server.tail1234.ts.net`.

---

**Todo**

- [ ] Rollback app version using tarballs on server
- [x] Install Tailscale to enable connecting livebook to the app in production
