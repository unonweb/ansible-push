#!/bin/bash

# BOILERPLATE
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")
ESC=$(printf "\e")
BOLD="${ESC}[1m"
RESET="${ESC}[0m"
CLEAR="\e[0m"
RED="${ESC}[31m"
GREEN="${ESC}[32m"
BLUE="${ESC}[34m"
MAGENTA="\e[35m"
GREY="${ESC}[37m"
CYAN="\e[36m"
UNDERLINE="${ESC}[4m"
BLINKINK="\033[5m"

# CONFIG & DEFAULTS
PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_DIR}/defaults.cfg"
PATH_DATA="${SCRIPT_PARENT}/data"
VERSION=1.12

if [[ -r ${PATH_CONFIG} ]]; then
	source "${PATH_CONFIG}"
else
	echo "<4>WARN: No config file found at ${PATH_CONFIG}. Using defaults ..."
	source "${PATH_DEFAULTS}"
fi

# IMPORTS
source ${SCRIPT_DIR}/lib/set_tags.sh
source ${SCRIPT_DIR}/lib/set_host.sh
source ${SCRIPT_DIR}/lib/set_playbook.sh

function main { # ${host} ${tags}

	ANSIBLE_HOST=${1:-""}
	ANSIBLE_TAGS=${2:-""}
	ANSIBLE_EXEC_PATH=$(which ansible)
	ANSIBLE_PLAYBOOK_EXEC_PATH=$(which ansible-playbook)
	
	local ansible_config_path="${ANSIBLE_REPO_PATH}/ansible.cfg"
	local vault_host_creds
	local vault_all_creds

	# PRINT version
	echo -ne "${GREY}"
	echo -e "Version: ${VERSION}"
	echo -ne "${CLEAR}"

	# CHECK exec path
	if [[ -z "${ANSIBLE_PLAYBOOK_EXEC_PATH}" ]]; then
		if [[ -f "/home/${USER}/.local/bin/ansible-playbook" ]]; then
			ANSIBLE_PLAYBOOK_EXEC_PATH="/home/${USER}/.local/bin/ansible-playbook"
		else
			echo "${MAGENTA}ansible-playbook executable not found. Tried:"
			echo "/home/${USER}/.local/bin/ansible-playbook${CLEAR}"
			exit 1
		fi
	fi
	
	# CHECK exec path
	if [[ -z "${ANSIBLE_EXEC_PATH}" ]]; then
		if [[ -f "/home/${USER}/.local/bin/ansible" ]]; then
			ANSIBLE_EXEC_PATH="/home/${USER}/.local/bin/ansible"
		else
			echo "${MAGENTA}ansible executable not found. Tried:"
			echo -e "/home/${USER}/.local/bin/ansible${CLEAR}"
			exit 1
		fi
	fi

	# MKDIR data
	if [[ ! -d "${PATH_DATA}" ]]; then
		mkdir "${PATH_DATA}"
	fi
	
	# CHECK repo path
	if [[ ! -d "${ANSIBLE_REPO_PATH}" ]]; then
		echo "ANSIBLE_REPO_PATH not found: ${ANSIBLE_REPO_PATH}"
		echo "Adjust config file at: ${PATH_CONFIG}. Exiting ..."
		exit 1
	fi

	# SET inventory path
	if [[ -f "${ANSIBLE_REPO_PATH}/inventory/inventory.yml" ]]; then
		ANSIBLE_INVENTORY_PATH="${ANSIBLE_REPO_PATH}/inventory/inventory.yml"
	else
		echo "ERROR: Path to inventory not found. Tried:"
		echo "${ANSIBLE_REPO_PATH}/inventory/inventory.yml"
		exit 1
	fi

	# SET host
	if [[ -z "${ANSIBLE_HOST}" ]]; then
		set_host
	fi

	# SET playbook path
	set_playbook

	# SET tags
	if [[ -z "${ANSIBLE_TAGS}" ]]; then
		set_tags
	fi

	# SET has_host_vault
	local host_vars_dirs
	local has_host_vault=0
	mapfile -t host_vars_dirs < <(find "${ANSIBLE_REPO_PATH}" -type d -name "host_vars")
	if [[ ${#host_vars_dirs[@]} -eq 1 ]]; then
		local vault_host_path="${host_vars_dirs[0]}/${ANSIBLE_HOST}/vault.yml"
		echo ${vault_host_path}
		if [[ -f "${host_vars_dirs[0]}/${ANSIBLE_HOST}/vault.yml" ]]; then
			has_host_vault=1
		fi
	else
		echo "No 'host_vars' directory found at ${ANSIBLE_REPO_PATH}"
	fi

	# SET vault_host_creds
	if ((has_host_vault)); then
		if [[ "${ANSIBLE_HOST}" == "$(hostname)" ]]; then
			# we'are running ansible against localhost
			if [[ -x "${VAULT_HOST_CREDS_LOOKUP_PATH}" ]]; then
				vault_host_creds="${VAULT_HOST_CREDS_LOOKUP_PATH}"
			else
				echo
				echo "In order to avoid asking for your own vault key everytime place a lookup script at ${VAULT_HOST_CREDS_LOOKUP_PATH} and make it executable."
				vault_host_creds="prompt"
			fi
		else
			vault_host_creds="prompt"
		fi
	fi

	# SET has_group_vault
	local group_vars_dirs
	local has_group_vault=0
	mapfile -t group_vars_dirs < <(find "${ANSIBLE_REPO_PATH}" -type d -name "group_vars")
	if [[ ${#group_vars_dirs[@]} -eq 1 ]]; then
		local vault_group_path="${group_vars_dirs[0]}/${VAULT_GROUP_NAME}/vault.yml"
		echo $vault_group_path
		if [[ -f "${group_vars_dirs[0]}/${VAULT_GROUP_NAME}/vault.yml" ]]; then
			has_group_vault=1
		fi
	else
		echo "No 'group_vars' directory found at ${ANSIBLE_REPO_PATH}"
	fi

	# SET vault_all_creds
	if ((has_group_vault)); then
		if [[ -f "${VAULT_GROUP_CREDS_LOOKUP_PATH}" ]]; then
			vault_all_creds="${VAULT_GROUP_CREDS_LOOKUP_PATH}"
		else
			vault_all_creds="prompt"
		fi
	fi

	# SET cmd
	local CMD="${ANSIBLE_PLAYBOOK_EXEC_PATH}"
	CMD+=" --inventory=${ANSIBLE_INVENTORY_PATH}"
	CMD+=" --tags "${ANSIBLE_TAGS}""
	if ((has_group_vault)); then
		CMD+=" --vault-id=${VAULT_GROUP_NAME}@${vault_all_creds}"
	fi
	if ((has_host_vault)); then
		CMD+=" --vault-id=${ANSIBLE_HOST}@${vault_host_creds}"
	fi
	CMD+=" ${ANSIBLE_PLAYBOOK_PATH}"

	# SET env
	if [[ -f "${ansible_config_path}" ]]; then
        CMD="ANSIBLE_CONFIG='${ANSIBLE_REPO_PATH}/ansible.cfg' ${CMD}"
	else
		echo "Ansible config not found at ${ansible_config_path}"
	fi

	# PRINT
	echo
	echo -e "${CYAN}Running ansible on host "${ANSIBLE_HOST}" with tags${CLEAR}: ${BOLD}${ANSIBLE_TAGS}${CLEAR} ..."
	echo -en "${GREY}"
	echo "${CMD}"
	echo
	echo -en "${CLEAR}"
	
	# RUN cmd
	eval "${CMD}"
}

main "${1:-""}" "${2:-""}"