ASSUMPTIONS
===========

- Only one playbook may be executed at once

VAULTS
======

It is assumed that one vault-id is used for each host. 
Therefore `--vault-id` flags for each host are added to the cmdline.
If a host does not have a vault, Ansible will log a warning, but proceed.
Another vault-id `all` is added, too.
More group vault-ids are currently not implemented as I dont use them.

The association of vault-ids and decryption methods may be managed from inside the script.
There are some lookup scripts included in run/ directory. 
They may be easily extended by placing others scripts (with `-client` suffix) inside this directory.
Then they may be associated with vault-ids from inside the script.

Attention!
If `VAULTS_USE_MASTER_PW_FOR_VAULT_PW_LOOKUP=1` is set, 
then a password for a keyring/database is asked and saved in encrypted form to `${XDG_RUNTIME_DIR}/${VAULTS_MASTER_PW_FILE_NAME}`.
It is intended to be used by a lookup script to get the vault pws for different vault-ids automatically.
The seed to encrypt the pw is passed to the lookup script as environment variable, which is not a safe method!
On exit or abort the script removes the file.

Lookup scripts
--------------

### vault-lookup-keepassxc-client.sh

The group path has to be relative to /root/
/root/ansible -> ansible
/root/ansible/vaults -> ansible/vaults

### Custom lookup scripts

Note the following official requirements to vault lookup scripts:

- Create a file with a name ending in either `-client` or `-client.EXTENSION`
- Make the file executable
- Within the script itself:
    - Print the passwords to standard output
    - Accept a `--vault-id` option
    - If the script prompts for data (for example, a database password), display the prompts to the TTY.