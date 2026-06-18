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
USE_VAULT_ALL=1
USE_VAULT_HOST=1

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

	# check exec path
	if [[ -z "${ANSIBLE_PLAYBOOK_EXEC_PATH}" ]]; then
		echo -ne "${GREY}"
		echo "ansible-playbook not found in PATH"
		echo -e "Trying /home/${USER}/.local/bin/ansible-playbook ..."
		echo -ne "${CLEAR}"
		if [[ -f "/home/${USER}/.local/bin/ansible-playbook" ]]; then
			ANSIBLE_PLAYBOOK_EXEC_PATH="/home/${USER}/.local/bin/ansible-playbook"
		else 
			exit 1
		fi
	fi
	
	# check exec path
	if [[ -z "${ANSIBLE_EXEC_PATH}" ]]; then
		echo -ne "${GREY}"
		echo "ansible not found in PATH"
		echo -e "Trying /home/${USER}/.local/bin/ansible ..."
		echo -ne "${CLEAR}"
		if [[ -f "/home/${USER}/.local/bin/ansible" ]]; then
			ANSIBLE_EXEC_PATH="/home/${USER}/.local/bin/ansible"
		else 
			exit 1
		fi
	fi

	# mkdir data
	if [[ ! -d "${PATH_DATA}" ]]; then
		mkdir "${PATH_DATA}"
	fi
	
	# check repo path
	if [[ ! -d "${ANSIBLE_REPO_PATH}" ]]; then
		echo "ANSIBLE_REPO_PATH not found: ${ANSIBLE_REPO_PATH}"
		echo "Adjust config file at: ${PATH_CONFIG}. Exiting ..."
		exit 1
	fi

	# build inventory path
	if [[ -f "${ANSIBLE_REPO_PATH}/inventory/inventory.yml" ]]; then
		ANSIBLE_INVENTORY_PATH="${ANSIBLE_REPO_PATH}/inventory/inventory.yml"
	else
		echo "ERROR: Path to inventory not found. Tried:"
		echo "${ANSIBLE_REPO_PATH}/inventory/inventory.yml"
		exit 1
	fi

	# set host
	if [[ -z "${ANSIBLE_HOST}" ]]; then
		set_host
	fi

	# set playbook path
	set_playbook

	# set tags
	if [[ -z "${ANSIBLE_TAGS}" ]]; then
		set_tags
	fi

	# how shall ansible prompt for vault with id corresponding to host
	if [[ "${ANSIBLE_HOST}" = "$(hostname)" ]]; then
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
	
	# how shall ansible prompt for vault with id 'all'
	if [[ -f "${VAULT_ALL_CREDS_LOOKUP_PATH}" ]]; then
		vault_all_creds="${VAULT_ALL_CREDS_LOOKUP_PATH}"
	else
		vault_all_creds="prompt"
	fi

	# build cmd
	local CMD="${ANSIBLE_PLAYBOOK_EXEC_PATH}"
	CMD+=" --inventory=${ANSIBLE_INVENTORY_PATH}"
	CMD+=" --tags "${ANSIBLE_TAGS}""
	if ((USE_VAULT_ALL)); then
		CMD+=" --vault-id=all@${vault_all_creds}"
	fi
	if ((USE_VAULT_HOST)); then
		CMD+=" --vault-id=${ANSIBLE_HOST}@${vault_host_creds}"
	fi
	CMD+=" ${ANSIBLE_PLAYBOOK_PATH}"

	# build env
	if [[ -f "${ansible_config_path}" ]]; then
        CMD="ANSIBLE_CONFIG='${ANSIBLE_REPO_PATH}/ansible.cfg' ${CMD}"
	else
		echo "Ansible config not found at ${ansible_config_path}"
	fi

	# feedback
	echo
	echo -e "${CYAN}Running ansible on host "${ANSIBLE_HOST}" with tags${CLEAR}: ${BOLD}${ANSIBLE_TAGS}${CLEAR} ..."
	echo -en "${GREY}"
	echo "${CMD}"
	echo -en "${CLEAR}"
	
	# run cmd
	eval "${CMD}"
}

main "${1:-""}" "${2:-""}"