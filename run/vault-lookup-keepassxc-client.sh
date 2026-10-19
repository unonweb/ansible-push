#!/usr/bin/env bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

# Using the same config file like un.ansible-push.sh
PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"

if [[ -r "${PATH_CONFIG}" ]]; then
	source "${PATH_CONFIG}"
else
	echo "ERROR: Path not found: ${PATH_CONFIG}" >&2
	exit 1
fi

function main {

	local keepass_db_path="${VAULTS_KEEPASS_DB_PATH}"
	local keepass_group="${VAULTS_KEEPASS_GROUP}"
	local keepass_title_prefix="${VAULTS_KEEPASS_TITLE_PREFIX}"
	local key_file="${XDG_RUNTIME_DIR:-${HOME}/.cache}/${VAULTS_MASTER_PW_FILE_NAME}"

	local vault_id=""
	if [[ "${1}" == "--vault-id" ]]; then
		# this is the way ansible calls this script
		vault_id="${2}"
	elif [[ -n "${1}" ]]; then
		# this not
		vault_id="${1}"
	fi

	# CHECKS
	# ------
	if [ -z "${vault_id}" ]; then
		echo "Error: No vault-id specified." >&2
		exit 1
	fi

	if [[ -z "${ANSIBLE_RAND_HEX}" ]]; then
		echo "Error: ANSIBLE_RAND_HEX not set" >&2
		exit 1
	fi
	
	if [ ! -f "${key_file}" ]; then
		echo "Error: No key found at: ${key_file}" >&2
		exit 1
	fi

	# MASTER PASS
	# -----------
	local master_pass
	# Attempt silent decryption using the environment seed
	master_pass=$(openssl enc -aes-256-cbc -pbkdf2 -d -in "${key_file}" -pass pass:"${ANSIBLE_RAND_HEX}" 2>/dev/null)
	
	if [[ -z "${master_pass}" ]]; then
		echo "Error: Failed to decrypt '${key_file}'." >&2
		exit 1
	fi

	# KEEPASS
	# -------
	local entry_path="${vault_id}"
	if [ -n "${keepass_group}" ]; then
		entry_path="${keepass_group}/${keepass_title_prefix} ${vault_id}"
	fi

	local secret
	secret=$(echo "${master_pass}" | keepassxc-cli show "${keepass_db_path}" "${entry_path}" -a password 2>/dev/null)
	
	if [ -z "${secret}" ]; then
		local matched_title=$(echo "${master_pass}" | keepassxc-cli search "${keepass_db_path}" "${vault_id}" 2>/dev/null | grep -i "${vault_id}" | head -n 1)
		if [ -n "${matched_title}" ]; then
			secret=$(echo "${master_pass}" | keepassxc-cli show "${keepass_db_path}" "${matched_title}" -a password 2>/dev/null)
		fi
	fi

	# RESULT
	# ------
	if [ -z "${secret}" ]; then
		echo "Error: Could not retrieve password for entry '${entry_path}' from '${keepass_db_path}" >&2
		exit 1
	fi

	echo -n "${secret}"
}

main ${@}