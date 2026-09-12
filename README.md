VARS
====

```sh
# Associate Vault-IDs with password lookup methods:
VAULT_MAP=(
    ["all"]="/path/to/lookup-script.sh"
)
# Add Vault-IDs that shall be added by default:
VAULT_DEFAULT_IDS
```

ASSUMPTIONS
===========

Only one playbook may be executed at once.
I assume one playbook per host.