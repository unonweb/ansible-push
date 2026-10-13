ASSUMPTIONS
===========

Only one playbook may be executed at once.

Ansible Vaults
--------------

The association of **vault-ids** and the password lookup method must be specified in `ansible.cfg`!

Example:
```yml
vault_identity_list = 
	vault-id-a@/path/to/lookup/script-client.sh,
	vault-id-b@prompt
```

Included lookup scripts
-----------------------

- KeepassXC: `run/vault-lookup-keepassxc-client.sh`

Use in your `ansible.cfg` with:
```yml
vault_identity_list = vault-id-a@/dest/path/to/vault-lookup-keepassxc-client.sh.sh
```


Attention!
If `VAULTS_USE_MASTER_PW_FOR_VAULT_PW_LOOKUP=1` is set, then a password for a keyring/database is asked and saved to `${XDG_RUNTIME_DIR}` or `${HOME}/.cache`. 
This pw is then used by the lookup script to get the vault pws for different vault-ids.

Custom lookup scripts
---------------------

Note the following official requirements to vault lookup scripts:

- Create a file with a name ending in either `-client` or `-client.EXTENSION`
- Make the file executable
- Within the script itself:
    - Print the passwords to standard output
    - Accept a `--vault-id` option
    - If the script prompts for data (for example, a database password), display the prompts to the TTY.