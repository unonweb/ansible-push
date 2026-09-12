#!/bin/bash

# REQUIRES
# --------
# - ANSIBLE_REPO_PATH

# RECOMMENDS
# ----------
# - VAULT_MAP
# - VAULT_DEFAULT_IDS

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
export PATH_DATA="${SCRIPT_PARENT}/data"
export PATH_DATA_LAST_HOST="${PATH_DATA}/last_host"
export PATH_DATA_LAST_TAGS="${PATH_DATA}/last_tags"
export VERSION=2
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
source ${SCRIPT_DIR}/lib/set_host.sh
source ${SCRIPT_DIR}/lib/set_playbook_path.sh
source ${SCRIPT_DIR}/lib/log.sh
source ${SCRIPT_DIR}/lib/debug.sh
source ${SCRIPT_DIR}/lib/set_inventory_path.sh
source ${SCRIPT_DIR}/lib/add_vault.sh
source ${SCRIPT_DIR}/lib/add_vault_flag.sh
source ${SCRIPT_DIR}/lib/get_possible_vaults.sh

function show_menu_tags {

	local options=(
		"Set" "Refresh List" "Return"
	)

	local default_choice=1
	local choice

	echo -e "${UNDERLINE}Edit Tags${CLEAR}"
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
		# Set
		1)
			set_tags
			return
			;;
		# Refresh List
		2)
			save_tag_list
			return
			;;
		# Return
		3)
			return
			;;
	esac
}

function show_menu_vaults {

	local options=(
		"Add host vault" "Add group vault" "Reset vaults" "Return"
	)

	local default_choice=1
	local choice

	echo -e "${UNDERLINE}Edit Vaults${CLEAR}"
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
			# Add host vault
			add_vault host
			return
			;;
		2)
			# Add group vault
			add_vault group
			return
			;;
		3)
			# Reset vaults
			VAULT_FLAGS=()
			return
			;;
		4)
			# Return
			return
			;;
	esac
}

function main {

	ANSIBLE_HOST=""
	ANSIBLE_TAGS=""
	ANSIBLE_EXEC_PATH=$(which ansible)
	ANSIBLE_PLAYBOOK_EXEC_PATH=$(which ansible-playbook)
	
	ANSIBLE_CONFIG_PATH="${ANSIBLE_REPO_PATH}/ansible.cfg"
	VAULT_FLAGS=()

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

	# INIT inventory path
	set_inventory_path

	# INIT possible vaults
	get_possible_vaults

	# INIT host
	if [[ -f "${PATH_DATA_LAST_HOST}" ]]; then
		ANSIBLE_HOST=$(< "${PATH_DATA_LAST_HOST}")
	else
		set_host
	fi

	# INIT tags
	if [[ -f "${PATH_DATA_LAST_HOST}" ]]; then
		ANSIBLE_TAGS=$(< "${PATH_DATA_LAST_TAGS}")
	else
		set_tags
	fi

	# INIT playbook path
	set_playbook_path

	# INIT vault flags
	add_vault_flag "${ANSIBLE_HOST}"
	for id in ${VAULT_DEFAULT_IDS}; do
		add_vault_flag "${id}"
	done

	# Main Menu
	local options=(
		"Host"
		"Tags"
		"Vaults"
		"Run Ansible"
		"Run Ansible (verbose)"
		"Exit"
	)

	# Set 1-based index for default option (e.g., 4 = "Run Ansible")
	local default_choice=4
	local choice

	while true; do

		# SET cmd
		local cmd="${ANSIBLE_PLAYBOOK_EXEC_PATH}"
		cmd+=" --inventory=${ANSIBLE_INVENTORY_PATH}"
		cmd+=" --tags "${ANSIBLE_TAGS}" "
		cmd+="${VAULT_FLAGS[@]}"
		cmd+=" ${ANSIBLE_PLAYBOOK_PATH}"
		# SET env
		if [[ -f "${ANSIBLE_CONFIG_PATH}" ]]; then
			cmd="ANSIBLE_CONFIG='${ANSIBLE_CONFIG_PATH}' ${cmd}"
		else
			echo "Ansible config not found at ${ANSIBLE_CONFIG_PATH}"
		fi

		# overview
		echo
		echo "-------------------------------"
		echo -e "Host:      ${GREEN}${ANSIBLE_HOST}${CLEAR}"
		echo -e "Playbook:  ${GREEN}${ANSIBLE_PLAYBOOK_PATH}${CLEAR}"
		echo -e "Inventory: ${GREEN}${ANSIBLE_INVENTORY_PATH}${CLEAR}"
		echo -e "Vaults:    ${GREEN}${VAULT_FLAGS[@]}${CLEAR}"
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
				# Host
				# ----
				echo
				set_host
				set_playbook_path
				# reset vaults
				VAULT_FLAGS=()
				for id in ${VAULT_DEFAULT_IDS}; do
					add_vault_flag "${id}"
				done
				add_vault_flag "${ANSIBLE_HOST}"
				;;
			2)
				# Tags
				# ----
				echo
				show_menu_tags
				;;
			3)
				# Vaults
				# ------
				echo
				show_menu_vaults
				;;
			4)
				# Run
				# ---
				# PRINT
				echo
				echo -e "${CYAN}Running ansible on host "${ANSIBLE_HOST}" with tags${CLEAR}: ${BOLD}${ANSIBLE_TAGS}${CLEAR} ..."
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
			5)
				# Run
				# --- 
				# (verbose)
				eval "${cmd} -v"
				;;
			6)
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