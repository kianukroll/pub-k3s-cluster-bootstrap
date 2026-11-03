#!/usr/bin/env bash
set -euo pipefail

failed=0

for file in "$@"; do
  if [[ ! -f "$file" ]]; then
    continue
  fi

  IFS= read -r first_line < "$file" || first_line=""
  if [[ "$first_line" != '$ANSIBLE_VAULT;'* ]]; then
    printf 'Vault file is not encrypted: %s\n' "$file" >&2
    failed=1
  fi
done

exit "$failed"