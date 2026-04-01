ASSUMPTIONS / RESTRICTIONS
==========================

Only the following Ansible Vaults (with IDs) are implemented in this script:
--vault-id=all
--vault-id=$(hostname)

This is due to how I use Ansible.


NOTES
=====

Executing `src/main.sh` from `run.sh` means we don't inherit the environment of the user (no PATH, no aliases).
Sourcing `src/main.sh` from `run.sh` means if we use exit in the first script we also exit the latter script!