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

function set_tags {
	# requires: 
	# - ANSIBLE_INVENTORY_PATH
	# - ANSIBLE_PLAYBOOK_PATH
	# sets:
	# - ANSIBLE_TAGS

	local tags_query
	local available_tags=()
	local out_name=$(basename ${ANSIBLE_PLAYBOOK_PATH})
	out_name="${out_name//.yml}" # remove .yml
	local out_path="${PATH_DATA}/tags.${out_name}"
	local run_tag_extraction=true

	# Check if the output file already exists
    if [[ -f "${out_path}" ]]; then
		echo
		echo "Tag list found: ${out_path}"
		echo -e "${CYAN}Use it?${CLEAR} (Enter)"
		echo -e "${CYAN}Recreate it?${CLEAR} (r)"
        read -p ">> " choice
        case "${choice}" in
            r)
				run_tag_extraction=true;;
            *) 
				run_tag_extraction=false;;
        esac
    fi

	if [[ "${run_tag_extraction}" == true ]]; then
		# get available tags
		echo
		echo -e "${BLINKINK}Searching for tags associated with playbook ...${CLEAR}"
		# Extracting TASK TAGS line
		local output_list_tags=$(ansible-playbook --list-tags --inventory "${ANSIBLE_INVENTORY_PATH}" "${ANSIBLE_PLAYBOOK_PATH}")
		# Removing the prefix and brackets
		task_tags_line="${output_list_tags#*TASK TAGS: }" # Remove from the beginning until TASK TAGS: 
		task_tags_line="${task_tags_line//[\[\]]/}" # Remove brackets
		# Converting the string into an array using IFS
		IFS=', ' read -r -a available_tags <<< "${task_tags_line}"

		if [[ ${#available_tags[@]} -eq 0 ]]; then
			echo "ERROR: Could not find any tags with playbook: ${ANSIBLE_PLAYBOOK_PATH} and inventory: ${ANSIBLE_INVENTORY_PATH}"
			exit 1
		else
			printf "%s\n" "${available_tags[@]}" > ${out_path}
			echo "Tag list saved to: ${out_path}"
		fi
	else
		readarray -t available_tags < "${out_path}"
        echo "Loaded ${#available_tags[@]} unique tags from file"
	fi

	# ask user
	echo
	echo -e "${CYAN}Enter tags${CLEAR}"
	echo -e "${GREY}Separator: comma${CLEAR}"
	echo -e "${GREY}Partial match is supported${CLEAR}"
	echo -e "${GREY}Leave empty to list available hosts${CLEAR}"
	read -p ">> " tags_query

	if [[ -z "${tags_query}" ]]; then
		# empty query
		# show full list
		select tag in "${available_tags[@]}"; do
			if [ -n "${tag}" ]; then
				ANSIBLE_TAGS="${tag}"
				echo "-> ${tag}"
				break
			else
				echo -e "${MAGENTA}Invalid choice – try again.${CLEAR}"
				continue
			fi
		done
	else
		# query
		tags_query=${tags_query,,} # make lowercase

		# find matches
		local matches=()
		for tag in "${available_tags[@]}"; do
			tag=${tag,,} # lowercase
			if [[ ${tag} == *"${tags_query}"* ]]; then
				matches+=("${tag}")
			fi
		done

		if [[ ${#matches[@]} -eq 0 ]]; then
			# no match
			echo -e "${MAGENTA}Could not find any matches. Please try again.${CLEAR}"
			# repeat
			set_tags
		elif [[ ${#matches[@]} -eq 1 ]]; then
			# one match
			ANSIBLE_TAGS="${matches[0]}"
			echo "-> ${ANSIBLE_TAGS}"
		else
			# more matches
			select choice in "${matches[@]}"; do
				if [[ -z ${choice} ]]; then
					echo -e "${MAGENTA}Invalid choice – try again.${CLEAR}"
					continue
				else
					ANSIBLE_TAGS="${choice}"
					echo "-> ${ANSIBLE_TAGS}"
					break
				fi
			done
		fi
	fi

	if [[ -n ${ANSIBLE_TAGS} ]]; then
		return 0
	else
		echo "ERROR: ANSIBLE_TAGS not set!"
		return 1
	fi
}

function set_host {
	# requires: 
	# - ANSIBLE_INVENTORY_PATH
	# sets:
	# - ANSIBLE_HOST

	local host_query
	local available_hosts

	while IFS= read -r line; do
		# remove leading whitespace characters
		line="${line#"${line%%[![:space:]]*}"}"
		# remove trailing whitespace characters
		line="${line%"${line##*[![:space:]]}"}"
		if [[ ${line} != hosts* && -n ${line} ]]; then
			available_hosts+=("${line}")
		fi
	done < <(ansible all --inventory=${ANSIBLE_INVENTORY_PATH} --list-hosts)

	if [[ ${#available_hosts[@]} -eq 0 ]]; then
		echo "ERROR: Could not find any hosts in inventory file: ${ANSIBLE_INVENTORY_PATH}"
		exit 1
	fi

	# ask user
	echo -e "${CYAN}Enter host name${CLEAR}"
	echo -e "${GREY}Partial match is supported${CLEAR}"
	echo -e "${GREY}Leave empty to list available hosts${CLEAR}"
	read -p ">> " host_query
	shopt -s nocasematch # make [[ string == pattern ]] case‑insensitive

	if [[ -z ${host_query} ]]; then
		# empty query
		select choice in "${available_hosts[@]}"; do
			if [[ -z ${choice} ]]; then
				echo -e "${MAGENTA}Invalid choice – try again.${CLEAR}"
				continue
			else
				ANSIBLE_HOST="${choice}"
				echo "-> ${ANSIBLE_HOST}"
				break
			fi
		done
	else
		# query
		host_query=${host_query,,} # make lowercase

		# find matches
		local matches=()
		for host in "${available_hosts[@]}"; do
			host=${host,,} # lowercase
			if [[ ${host} == *"${host_query}"* ]]; then
				matches+=("${host}")
			fi
		done

		if [[ ${#matches[@]} -eq 0 ]]; then
			# no match
			echo -e "${MAGENTA}Could not find any matches. Please try again.${CLEAR}"
			# repeat
			set_host
		elif [[ ${#matches[@]} -eq 1 ]]; then
			# one match
			ANSIBLE_HOST="${matches[0]}"
			echo "-> ${ANSIBLE_HOST}"
		else
			# more matches
			select choice in "${matches[@]}"; do
				if [[ -z ${choice} ]]; then
					echo -e "${MAGENTA}Invalid choice – try again.${CLEAR}"
					continue
				else
					ANSIBLE_HOST="${choice}"
					echo "-> ${ANSIBLE_HOST}"
					break
				fi
			done
		fi
	fi

	if [[ -n ${ANSIBLE_HOST} ]]; then
		return 0
	else
		echo "ERROR: ANSIBLE_HOST not set!"
		return 1
	fi
}

function main { # ${host} ${tags}

	ANSIBLE_HOST=${1:-""}
	ANSIBLE_TAGS=${2:-""}

	local vault_host_creds
	local vault_all_creds

	local ansible_exec_path=$(which ansible-playbook)

	if [[ -z "${ansible_exec_path}" ]]; then
		echo "ansible-playbook not found in PATH"
		echo -e "Trying ${GREY}/home/${USER}/.local/bin/ansible-playbook${CLEAR} ..."
		if [[ -f "/home/${USER}/.local/bin/ansible-playbook" ]]; then
			ansible_exec_path="/home/${USER}/.local/bin/ansible-playbook"
		else 
			exit 1
		fi
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