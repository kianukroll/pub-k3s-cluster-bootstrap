# Ansible

## Pre-Commit

Install and activate the repository hooks once:

```bash
pipx install pre-commit
pre-commit install
```

Run all checks manually with:

```bash
pre-commit run --all-files
```

The hooks run `ansible-lint` and verify that every `99-vault.yml` file starts
with the Ansible Vault header `$ANSIBLE_VAULT;`. A plaintext vault file is
rejected before it can be committed.

Role configuration is kept in the production inventory under
`inventory/prod/group_vars`; the roles do not contain separate default
variable files.

Argo CD is installed after K3s on the first control-plane node with Helm. The
role installs the pinned Helm release, deploys the pinned Argo CD chart, waits
for the server deployment, and applies `argocd/root-bootstrap-app.yaml`. The
admin password is stored as a bcrypt hash in the encrypted
`inventory/prod/group_vars/k3s_cluster/99-vault.yml` file. Its modification
timestamp is configured separately as the non-secret
`argocd_admin_password_mtime` setting; update it whenever the password
changes.

## Vault Files

Keep sensitive domains, IP addresses, tokens, and keys in encrypted
`99-vault.yml` files. Create or edit them with Ansible Vault:

```bash
ansible-vault edit inventory/prod/group_vars/nebula_nodes/99-vault.yml
ansible-vault view inventory/prod/group_vars/nebula_nodes/99-vault.yml
```

The local `ansible/.vault_pass` file is ignored and must never be committed.
Encrypted `99-vault.yml` files may be committed; plaintext sensitive values
must not be added to public `10-*.yml` files.

## Host Preparation

The production security variables disable swap during host preparation. Active
swap is turned off immediately, and swap entries in `/etc/fstab` are commented
out so they remain disabled after reboot.

To encrypt or decrypt all `99-vault.yml` files at once, run the scripts from
the repository root:

```bash
./scripts/encrypt-ansible-vault-files.sh
./scripts/decrypt-ansible-vault-files.sh
```

Both scripts use `ansible/.vault_pass` by default. Set `VAULT_PASSWORD_FILE`
to use another password file. Decryption is intended for local editing only;
encrypt the files again before committing.

runnning ansible playbook
``` bash
ansible-playbook -i ./inventory/prod/hosts.yml site.yml
```
