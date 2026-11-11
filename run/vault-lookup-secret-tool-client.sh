#!/usr/bin/bash

ATTRIBUTE="ansible-vault"

if [[ "${1}" == "--vault-id" ]]; then
	vault_id="${2}"
elif [[ -n "${1}" ]]; then
	vault_id="${1}"
fi

secret-tool lookup "${ATTRIBUTE} "${vault_id}"
