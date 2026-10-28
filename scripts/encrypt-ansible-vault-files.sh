#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
vault_root="${repo_root}/ansible/inventory"
vault_password_file="${VAULT_PASSWORD_FILE:-${repo_root}/ansible/.vault_pass}"

if [[ ! -f "$vault_password_file" ]]; then
  printf 'Vault password file not found: %s\n' "$vault_password_file" >&2
  exit 1
fi

vault_files=()
while IFS= read -r -d '' file; do
  vault_files+=("$file")
done < <(find "$vault_root" -type f -name '99-vault.yml' -print0)

if (( ${#vault_files[@]} == 0 )); then
  printf 'No Ansible Vault files found below %s\n' "$vault_root"
  exit 0
fi

encrypted=0
for file in "${vault_files[@]}"; do
  IFS= read -r first_line < "$file" || first_line=""
  if [[ "$first_line" == '$ANSIBLE_VAULT;'* ]]; then
    printf 'Already encrypted: %s\n' "${file#"$repo_root"/}"
    continue
  fi

  ansible-vault encrypt --vault-password-file "$vault_password_file" "$file"
  encrypted=$((encrypted + 1))
  printf 'Encrypted: %s\n' "${file#"$repo_root"/}"
done

printf 'Encrypted %d file(s).\n' "$encrypted"
