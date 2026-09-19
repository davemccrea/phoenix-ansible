project := `awk '/^project_name:/ {print $2}' group_vars/all/vars.yml`
user := `awk -F' *= *' '/^remote_user/ {print $2}' ansible.cfg`

# List recipes
default:
    @just --list --unsorted

# Install Ansible collections (pass --upgrade to update them)
install *args:
    ansible-galaxy collection install -r requirements.yml {{args}}

# Lint playbooks and roles
lint:
    ansible-lint

# Edit a vault: `just vault` for shared, `just vault <host>` for a host
vault host="all":
    ansible-vault edit {{ if host == "all" { "group_vars/all/vault.yml" } else { "host_vars/" + host + "/vault.yml" } }}

# Bootstrap a fresh server as root (run once)
bootstrap host:
    ansible-playbook playbooks/bootstrap.yml -l {{host}}

# Dry run: show what provisioning would change (host or `all`)
check host:
    ansible-playbook site.yml -l {{host}} --check --diff

# Provision a host, or `all` for every server
provision host *args:
    ansible-playbook site.yml -l {{host}} {{args}}

# SSH into a host
ssh host:
    ssh {{user}}@$(just _ip {{host}})

# Tail app logs
logs host:
    ssh -t {{user}}@$(just _ip {{host}}) docker logs -f {{project}}

# Open an IEx remote shell in the running app
iex host:
    ssh -t {{user}}@$(just _ip {{host}}) docker exec -it {{project}} /app/bin/{{project}} remote

_ip host:
    @awk -v h={{host}} '$1 == h { sub(/.*ansible_host=/, ""); print $1 }' inventory.ini
