# Simple Phoenix deployment with Ansible

> [!NOTE]
> Intended for use on Ubuntu.

By "simple" I mean the following:

- A single server
- Docker Compose for the app and Cloudflare Tunnel
- Postgres on the same server, managed by Ansible
- App deployment handled by GitHub Actions (not Ansible)

The app and `cloudflared` run as Docker containers. Postgres runs directly on the host. Ansible handles server setup only — app deployments are done via GitHub Actions, which builds a Docker image, pushes it to ghcr.io, and pulls it onto the server.

## Getting started

Make sure Ansible is installed and that you have SSH access to the target server.

### Install requirements

```bash
ansible-galaxy install -r requirements.yml
```

To upgrade all collections to their latest versions:

```bash
ansible-galaxy collection install -r requirements.yml --upgrade
```

### Add host

Specify the target host by updating the `inventory.ini` file:

```ini
[hosts]
123.123.123.123
```

### Update vars file

Modify `group_vars/hosts/vars` to reflect your environment:

```yaml
user: david
app_port: 4000
project_name: my_app       # Should match your Phoenix project name
project_url: myapp.example.com
github_username: myusername
# etc...
```

### Create a vault

Ansible Vault is used to encrypt sensitive data. To create a new vault:

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
vault_token_signing_secret: secret
vault_release_cookie: secret
vault_stripe_api_key: secret
vault_stripe_webhook_secret: secret
vault_here_api_key: secret
vault_tailscale_authkey: secret
vault_cloudflare_tunnel_token: secret
```

The Cloudflare Tunnel token is obtained from the Cloudflare Zero Trust dashboard when you create a tunnel. Point the tunnel's public hostname at `http://localhost:<app_port>`.

## Playbooks

### Create user

Creates the user defined in `group_vars/hosts/vars` and disables SSH root access. Run once.

```bash
ansible-playbook 01-bootstrap.yml
```

### Configure server

Once the user is created, configure the server:

```bash
ansible-playbook 02-site.yml
```

This playbook:

- Installs updates and applies basic security hardening (UFW, fail2ban, SSH)
- Installs and configures Postgres, creates the database and user
- Installs Tailscale
- Installs Docker
- Places the `docker-compose.yml` at `/opt/<project_name>/docker-compose.yml`

> [!NOTE]
> UFW only opens port 22 (SSH) and the Tailscale interface. Ports 80/443 are not needed — all traffic arrives via the Cloudflare Tunnel.

### App deployment

App deployment is handled by GitHub Actions in the Phoenix app repo, not by Ansible. The workflow:

1. Builds a Docker image from the app's `Dockerfile`
2. Pushes the image to `ghcr.io/<github_username>/<project_name>`
3. SSHes into the server, updates the image tag in `docker-compose.yml`, and runs `docker compose up -d`
4. Runs database migrations via `docker compose exec app bin/migrate`

## Connect with Livebook

Start Livebook on your local machine.

Use "Attached Node" to connect to the Elixir node running on the server. The node name is the Tailscale hostname plus the tailnet name, e.g. `my_app@my-server.tail1234.ts.net`.
