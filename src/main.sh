#!/bin/bash

# REQUIRES
# --------
# - ANSIBLE_REPO_PATH

# BOILERPLATE
# -----------
export SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
export SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
export SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
export SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")
export ESC=$(printf "\e")
export BOLD="${ESC}[1m"
export RESET="${ESC}[0m"
export CLEAR="\e[0m"
export RED="${ESC}[31m"
export GREEN="${ESC}[32m"
export BLUE="${ESC}[34m"
export MAGENTA="\e[35m"
export GREY="\033[38;5;248m"
export CYAN="\e[36m"
export UNDERLINE="${ESC}[4m"
export BLINKING="\033[5m"

# CONFIG & DEFAULTS
# -----------------
export PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
export PATH_DEFAULTS="${SCRIPT_DIR}/defaults.cfg"
export PATH_RUN="${SCRIPT_PARENT}/run"
export PATH_STATE="${SCRIPT_PARENT}/state"
export PATH_STATE_LAST_PLAYBOOK="${PATH_STATE}/last_playbook"
export PATH_STATE_LAST_TAGS="${PATH_STATE}/last_tags"
export PATH_STATE_VAULT_MAP="${PATH_STATE}/vault_id_map"
export VERSION=261029
export DEBUG=1
export LOG=0

if [[ -r ${PATH_CONFIG} ]]; then
	source "${PATH_CONFIG}"
else
	echo "<4>WARN: No config file found at ${PATH_CONFIG}. Using defaults ..."
	source "${PATH_DEFAULTS}"
fi

# IMPORTS
# -------
source ${SCRIPT_DIR}/lib/save_tag_list.sh
source ${SCRIPT_DIR}/lib/set_tags.sh
source ${SCRIPT_DIR}/lib/set_playbook_path.sh
source ${SCRIPT_DIR}/lib/set_master_pw.sh
source ${SCRIPT_DIR}/lib/log.sh
source ${SCRIPT_DIR}/lib/map_vault_id_to_method.sh
source ${SCRIPT_DIR}/lib/set_inventory_path.sh
source ${SCRIPT_DIR}/lib/menu_tags.sh
source ${SCRIPT_DIR}/lib/menu_lint.sh

function main {

	if ((VAULTS_USE_MASTER_PW_FOR_VAULT_PW_LOOKUP)); then
		if [[ -z "${VAULTS_MASTER_PW_FILE_NAME}" ]]; then
			echo "ERROR: Var empty: VAULTS_MASTER_PW_FILE_NAME"
			return 1
		fi
		# Use XDG_RUNTIME_DIR (RAM-backed tmpfs, strictly 0700 perms)
		MASTER_PW_FILE="${XDG_RUNTIME_DIR}/${VAULTS_MASTER_PW_FILE_NAME}"

		# Automatically wipe the key file from RAM when the wrapper exits
		trap 'rm -f "${MASTER_PW_FILE}"' EXIT
	fi

	ANSIBLE_TAGS=""
	ANSIBLE_EXEC_PATH=$(which ansible)
	ANSIBLE_PLAYBOOK_EXEC_PATH=$(which ansible-playbook)
	ANSIBLE_CONFIG_PATH="${ANSIBLE_REPO_PATH}/ansible.cfg"

	# CHMOD
	chmod u=rwx,g=,o= ${PATH_RUN}/*

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
	if [[ ! -d "${PATH_STATE}" ]]; then
		mkdir "${PATH_STATE}"
	fi
	
	# CHECK repo path
	if [[ ! -d "${ANSIBLE_REPO_PATH}" ]]; then
		echo "ANSIBLE_REPO_PATH not found: ${ANSIBLE_REPO_PATH}"
		echo "Adjust config file at: ${PATH_CONFIG}. Exiting ..."
		exit 1
	fi

	# INIT inventory path
	set_inventory_path

	# INIT playbook
	if [[ -f "${PATH_STATE_LAST_PLAYBOOK}" ]]; then
		ANSIBLE_PLAYBOOK_PATH=$(< "${PATH_STATE_LAST_PLAYBOOK}")
	else
		set_playbook_path
	fi

	# INIT tags
	if [[ -f "${PATH_STATE_LAST_TAGS}" ]]; then
		ANSIBLE_TAGS=$(< "${PATH_STATE_LAST_TAGS}")
	else
		set_tags
	fi

	# Main Menu
	local options=(
		"Playbook"
		"Tags"
		"Lint"
		"Vault IDs"
		"Run Ansible"
		"Run Ansible (verbose)"
		"Exit"
	)

	# Set 1-based index for default option (e.g., 4 = "Run Ansible")
	local default_choice=5
	local choice
	
	echo
	echo -ne "${GREY}"
	echo -e "Version:   ${VERSION}"
	echo -ne "${CLEAR}"
	while true; do

		local target_hosts=(
			$("${SCRIPT_DIR}/lib/parse_hosts.py" "${ANSIBLE_PLAYBOOK_PATH}")
		)

		local vault_ids=(
			${target_hosts[@]} 
			all
		)

		local vault_id_flags=()
		if [[ -f "${PATH_STATE_VAULT_MAP}" ]]; then
			# sets VAULT_MAP_ID_TO_METHOD
			source "${PATH_STATE_VAULT_MAP}"
		else
			declare -A VAULT_MAP_ID_TO_METHOD
		fi

		for id in "${vault_ids[@]}"; do
			local method="prompt"
			if [[ -v VAULT_MAP_ID_TO_METHOD["${id}"] ]]; then
				method="${VAULT_MAP_ID_TO_METHOD["${id}"]}"
			fi
			vault_id_flags+=("--vault-id ${id}@${method}")
		done

		# SET cmd
		local cmd="${ANSIBLE_PLAYBOOK_EXEC_PATH}"
		cmd+=" --inventory=${ANSIBLE_INVENTORY_PATH}"
		cmd+=" --tags ${ANSIBLE_TAGS}"
		cmd+=" ${vault_id_flags[@]}"
		cmd+=" ${ANSIBLE_PLAYBOOK_PATH}"
		
		# PREPEND env
		if [[ -f "${ANSIBLE_CONFIG_PATH}" ]]; then
			cmd="ANSIBLE_CONFIG='${ANSIBLE_CONFIG_PATH}' ${cmd}"
		else
			echo "Ansible config not found at ${ANSIBLE_CONFIG_PATH}"
		fi

		# overview
		# echo -e "Inventory: ${GREEN}${ANSIBLE_INVENTORY_PATH}${CLEAR}"
		local playbook_name=$(basename ${ANSIBLE_PLAYBOOK_PATH})

		# PRINT version
		echo "-------------------------------"
		echo -e "${BOLD}Playbook:${CLEAR}  ${GREEN}${BOLD}${playbook_name}${CLEAR}"
		echo -e "Hosts:     ${GREEN}${target_hosts[@]}${CLEAR}"
		echo -e "Vault IDs: ${GREEN}${vault_ids[@]}${CLEAR}"
		echo -e "Tags:      ${GREEN}${ANSIBLE_TAGS}${CLEAR}"
		echo "-------------------------------"
		echo

		# menu
		echo -e "${UNDERLINE}Main Menu${CLEAR}"
		for i in "${!options[@]}"; do
			local index=$((i + 1))
			if [[ ${index} -eq ${default_choice} ]]; then
				#printf "%d) %s [default]\n" "${index}" "${options[${i}]}"
				echo -e "${BOLD}${index}) ${options[${i}]}${CLEAR}"
			else
				# printf "%d) %s\n" "${index}" "${options[${i}]}"
				echo -e "${index}) ${options[${i}]}"
			fi
		done

		read -r -p ">> " choice
		
		# If user pressed Enter, use the default
		choice="${choice:-${default_choice}}"

		case "${choice}" in
			1)
				# Playbook
				# --------
				echo
				set_playbook_path
				;;
			2)
				# Tags
				# ----
				echo
				menu_tags
				;;
			3)
				# Lint
				# ----
				echo
				menu_lint
				;;
			4)
				# Vault IDs
				# ---------
				map_vault_id_to_method ${vault_ids[@]}
				;;
			5)
				# Run
				# ---
				echo
				set_master_pw

				if [[ -n "${ANSIBLE_RAND_HEX}" ]]; then
					cmd="ANSIBLE_RAND_HEX='${ANSIBLE_RAND_HEX}' ${cmd}"
				else
					echo "ANSIBLE_RAND_HEX not set"
				fi

				# PRINT
				echo
				echo -e "${CYAN}Running Ansible Playbook "${ANSIBLE_PLAYBOOK_PATH}" with tags${CLEAR}: ${BOLD}${ANSIBLE_TAGS}${CLEAR} ..."
				echo -en "${GREY}"
				echo "${cmd}"
				echo
				echo -en "${CLEAR}"
				
				# RUN cmd
				eval "${cmd}"
				
				if [[ ${?} -ne 0 ]]; then
					echo -e "${MAGENTA}Script returned error code: ${exit_code}${RESET}"
					echo
				fi
				;;
			6)
				# Run
				# --- 
				# (verbose)

				set_master_pw
				
				eval "${cmd} -v"
				;;
			7)
				# Exit
				# ----
				exit 0
				;;
			
			*)
				echo "Bad option: ${REPLY}"
				;;
		esac
	done
}

main