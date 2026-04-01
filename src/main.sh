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

# CONFIG & DEFAULTS
PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_DIR}/defaults.cfg"
USE_VAULT_ALL=1
USE_VAULT_HOST=1

if [[ -r ${PATH_CONFIG} ]]; then
	source "${PATH_CONFIG}"
else
	echo "<4>WARN: No config file found at ${PATH_CONFIG}. Using defaults ..."
	source "${PATH_DEFAULTS}"
fi

function main() { # ${host} ${tags}

	local host=${1:-""}
	local tags=${2:-""}

	local vault_host_creds
	local vault_all_creds

	local ansible_exec_path=$(which ansible-playbook)

	if [[ -z "${ansible_exec_path}" ]]; then
		echo "ansible-playbook not found in PATH"
		echo -e "Trying ${GREY}/home/${USER}/.local/bin/ansible-playbook${CLEAR} ..."
		if [[ -f "/home/${USER}/.local/bin/ansible-playbook" ]]; then
			ansible_exec_path="/home/${USER}/.local/bin/ansible-playbook"
		else 
			return 1
		fi
	fi
	
	if [[ ! -d "${ANSIBLE_REPO_PATH}" ]]; then
		echo "ANSIBLE_REPO_PATH not found: ${ANSIBLE_REPO_PATH}"
		echo "Adjust config file at: ${PATH_CONFIG}. Exiting ..."
		return 1
	fi

	if [[ -z "${host}" ]]; then
		echo
		echo -e "${CYAN}Enter host name${CLEAR}"
		if [[ ${#HOSTS[@]} -gt 0 ]]; then
			echo -e "${GREY}Leave empty for suggestions${CLEAR}"
		fi
		read -p ">> " host
		if [[ -z "${host}" ]]; then
			select item in "${HOSTS[@]}"; do
				if [ -n "${item}" ]; then
					# remove " [user]" from the host string
					host="${item%% \[*}" # remove " [*" from the end
					echo "-> ${host}"
					break
				else
					echo "Invalid selection. Try again."
				fi
			done
		fi
	fi

	# build playbook path
	if [[ -f "${ANSIBLE_REPO_PATH}/playbooks/${host}.yml" ]]; then
		ansible_playbook_path="${ANSIBLE_REPO_PATH}/playbooks/${host}.yml"
	elif [[ -f "${ANSIBLE_REPO_PATH}/playbooks/hosts.${host}.yml" ]]; then
		ansible_playbook_path="${ANSIBLE_REPO_PATH}/playbooks/hosts.${host}.yml"
	else
		echo "ERROR: Path to playbook not found. Tried:"
		echo "${ANSIBLE_REPO_PATH}/playbooks/${host}.yml"
		echo "${ANSIBLE_REPO_PATH}/playbooks/hosts.${host}.yml"
		echo -e "${CYAN}Enter path${CLEAR}"
		read -p ">> " ansible_playbook_path
	fi

	# build inventory path
	if [[ -f "${ANSIBLE_REPO_PATH}/inventory/inventory.yml" ]]; then
		ansible_inventory_path="${ANSIBLE_REPO_PATH}/inventory/inventory.yml"
	else
		echo "ERROR: Path to inventory not found. Tried:"
		echo "${ANSIBLE_REPO_PATH}/inventory/inventory.yml"
		return 1
	fi

	if [[ -z "${tags}" ]]; then
		echo
		echo -e "${CYAN}Enter tags${CLEAR}"
		echo -e "${GREY}Separator: comma${CLEAR}"
		echo -e "${GREY}Leave empty for suggestions${CLEAR}"
		read -p ">> " tags
		if [[ -z "${tags}" ]]; then
			# Extracting TASK TAGS line
			local output_list_tags=$(ansible-playbook --list-tags --inventory "${ansible_inventory_path}" "${ansible_playbook_path}")
			#task_tags_line=$(echo "${output_list_tags}" | grep "TASK TAGS:")
			# Removing the prefix and brackets
			task_tags_line="${output_list_tags#*TASK TAGS: }" # Remove from the beginning until TASK TAGS: 
			task_tags_line="${task_tags_line//[\[\]]/}" # Remove brackets
			# Converting the string into an array using IFS
			local tags_array=()
			IFS=', ' read -r -a tags_array <<< "${task_tags_line}"

			select tag in "${tags_array[@]}"; do
				if [ -n "${tag}" ]; then
					echo "-> ${tag}"
					tags="${tag}"
					break
				else
					echo "Invalid selection. Try again."
				fi
			done			
		fi
	fi

	# how shall ansible prompt for vault with id corresponding to host
	if [[ "${host}" = "$(hostname)" ]]; then
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
	CMD+=" --inventory=${ansible_inventory_path}"
	CMD+=" --tags "${tags}""
	if ((USE_VAULT_ALL)); then
		CMD+=" --vault-id=all@${vault_all_creds}"
	fi
	if ((USE_VAULT_HOST)); then
		CMD+=" --vault-id=${host}@${vault_host_creds}"
	fi
	CMD+=" ${ansible_playbook_path}"

	# feedback
	echo
	echo -e "${CYAN}Running ansible on host "${host}" with tags: "${tags}"${CLEAR} ..."
	echo -en "${GREY}"
	echo ${CMD}
	echo -en "${CLEAR}"
	
	# run cmd
	ANSIBLE_HASH_BEHAVIOUR=merge ${CMD}

	#ANSIBLE_HASH_BEHAVIOUR=merge ansible-playbook \
	#--vault-id=all@${VAULT_ALL_CREDS_LOOKUP_PATH} \
	#--vault-id=${host}@${vault_host_creds} \
	#--inventory=${ANSIBLE_REPO_PATH}/inventory/inventory.yml \
	#--tags "${tags}" \
	#${ANSIBLE_REPO_PATH}/playbooks/${host}.yml
}

main "${1:-""}" "${2:-""}"