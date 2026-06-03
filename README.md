# Phoenix Server Setup with Ansible

> [!NOTE]
> Intended for use on Ubuntu or Debian.

By "simple" I mean the following:

- A single server
- Docker Compose for the app and Cloudflare Tunnel
- Postgres on the same server, managed by Ansible
- App deployment handled by GitHub Actions (not Ansible)

The app and `cloudflared` run as Docker containers. Postgres runs directly on the host. Ansible handles server setup only. App deployments are handled separately via GitHub Actions, which builds a Docker image, pushes it to ghcr.io, and pulls it onto the server.

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

Specify the target host by updating `inventory.ini`:

```ini
[web]
edenflowers ansible_host=1.2.3.4
```

### Update vars file

Modify `host_vars/<host>/vars.yml` to reflect your environment:

```yaml
user: david
app_port: 4000
project_name: my_app       # Should match your Phoenix project name
project_url: myapp.example.com
# etc...
```

### Create a vault

Ansible Vault is used to encrypt sensitive values. See `host_vars/<host>/vault.example.yml` for the full list of required `vault_*` variables with placeholder values and generation hints.

> [!IMPORTANT]
> The variables in `vars.yml` and `vault.example.yml` reflect **my specific deployment** (Stripe, Google OAuth, HERE Maps, imgproxy, Cloudflare Tunnel, etc.). They are not a generic template. Treat them as a reference: add, remove, or rename keys to match the services your own app actually uses, and update `roles/common/templates/` and `roles/common/tasks/` accordingly.

The quickest path:

```bash
cp host_vars/<host>/vault.example.yml host_vars/<host>/vault.yml
# edit values, then:
ansible-vault encrypt host_vars/<host>/vault.yml
```

Or create an empty encrypted file and paste the keys in:

```bash
ansible-vault create host_vars/<host>/vault.yml
```

To edit the vault later:

```bash
ansible-vault edit host_vars/<host>/vault.yml
```

To avoid entering the vault password on each run, store it in `.vault_pass` (already gitignored):

```bash
echo 'my_vault_password' > .vault_pass
```

The Cloudflare Tunnel token is obtained from the Cloudflare Zero Trust dashboard when you create a tunnel. Point the tunnel's public hostname at `http://localhost:<app_port>`.

## Usage

### Bootstrap (once, on a fresh server)

Creates the user defined in `vars.yml`, sets up SSH keys, and disables root login. Run once as root on a freshly provisioned server:

```bash
ansible-playbook playbooks/bootstrap.yml
```

### Provision

Configures the server in full:

```bash
ansible-playbook site.yml
```

This role:

- Updates packages and reboots if required
- Applies security hardening (UFW, fail2ban, SSH)
- Installs and connects Tailscale
- Installs and configures Postgres, creates the database and user
- Installs Docker and logs in to ghcr.io
- Places `docker-compose.yml` at `/opt/<project_name>/docker-compose.yml`
- Schedules daily Postgres backups

> [!NOTE]
> UFW only opens port 22 (SSH) and the Tailscale interface. Ports 80/443 are not needed, all traffic arrives via the Cloudflare Tunnel.

### App deployment

App deployment is handled by GitHub Actions in the Phoenix app repo, not by Ansible. The workflow:

1. Builds a Docker image from the app's `Dockerfile`
2. Pushes the image to `ghcr.io/<github_username>/<project_name>`
3. SSHes into the server, updates the image tag in `docker-compose.yml`, and runs `docker compose up -d`
4. Runs database migrations via `docker compose exec app bin/migrate`

#### SSH key setup for GitHub Actions

Generate a dedicated key pair:

```bash
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions -N ""
```

Add the public key to `host_vars/<host>/vars.yml`:

```yaml
github_actions_public_key: "ssh-ed25519 AAAA... github-actions"
```

It will be added to `authorized_keys` when you run `playbooks/bootstrap.yml`. Add the private key (`cat ~/.ssh/github_actions`) as a GitHub Actions secret (e.g. `SSH_PRIVATE_KEY`) in your app repo.

## Tail app logs

```bash
ssh <user>@<tailscale_hostname>.<tailscale_tailnet_name> docker logs -f <project_name>
```

## Connect with Livebook

Start Livebook on your local machine.

Use "Attached Node" to connect to the Elixir node running on the server. The node name is the Tailscale hostname plus the tailnet name, e.g. `my_app@my-server.tail1234.ts.net`.

## IEx remote shell

SSH into the server, then:

```bash
docker exec -it <project_name> /app/bin/<app_name> remote
```
