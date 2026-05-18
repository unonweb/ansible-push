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

# MAIN
function main { # ${host} ${tags}

	ANSIBLE_HOST=${1:-""}
	ANSIBLE_TAGS=${2:-""}

	local vault_host_creds
	local vault_all_creds

	local ansible_exec_path=$(which ansible-playbook)

	# check ansible binary
	if [[ -z "${ansible_exec_path}" ]]; then
		echo "ansible-playbook not found in PATH"
		echo -e "Trying ${GREY}/home/${USER}/.local/bin/ansible-playbook${CLEAR} ..."
		if [[ -f "/home/${USER}/.local/bin/ansible-playbook" ]]; then
			ansible_exec_path="/home/${USER}/.local/bin/ansible-playbook"
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

	# build playbook path
	if [[ -f "${ANSIBLE_REPO_PATH}/playbooks/${ANSIBLE_HOST}.yml" ]]; then
		ANSIBLE_PLAYBOOK_PATH="${ANSIBLE_REPO_PATH}/playbooks/${ANSIBLE_HOST}.yml"
	elif [[ -f "${ANSIBLE_REPO_PATH}/playbooks/hosts.${ANSIBLE_HOST}.yml" ]]; then
		ANSIBLE_PLAYBOOK_PATH="${ANSIBLE_REPO_PATH}/playbooks/hosts.${ANSIBLE_HOST}.yml"
	else
		echo "ERROR: Path to playbook not found. Tried:"
		echo "${ANSIBLE_REPO_PATH}/playbooks/${ANSIBLE_HOST}.yml"
		echo "${ANSIBLE_REPO_PATH}/playbooks/hosts.${ANSIBLE_HOST}.yml"
		echo -e "${CYAN}Enter path${CLEAR}"
		read -p ">> " ANSIBLE_PLAYBOOK_PATH
	fi

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
	local CMD="${ansible_exec_path}"
	CMD+=" --inventory=${ANSIBLE_INVENTORY_PATH}"
	CMD+=" --tags "${ANSIBLE_TAGS}""
	if ((USE_VAULT_ALL)); then
		CMD+=" --vault-id=all@${vault_all_creds}"
	fi
	if ((USE_VAULT_HOST)); then
		CMD+=" --vault-id=${ANSIBLE_HOST}@${vault_host_creds}"
	fi
	CMD+=" ${ANSIBLE_PLAYBOOK_PATH}"

	# feedback
	echo
	echo -e "${CYAN}Running ansible on host "${ANSIBLE_HOST}" with tags: "${ANSIBLE_TAGS}"${CLEAR} ..."
	echo -en "${GREY}"
	echo ${CMD}
	echo -en "${CLEAR}"
	
	# run cmd
	${CMD}
}

main "${1:-""}" "${2:-""}"