# REQUIRES
# --------
# - ANSIBLE_REPO_PATH
# - PATH_DATA_LAST_PLAYBOOK

# SETS
# ----
# - ANSIBLE_PLAYBOOK_PATH

function set_playbook_path {

	# Trap SIGINT (CTRL+C)
	local old_trap=$(trap -p SIGINT)
    trap 'return 0' SIGINT

	# ask user
	local playbook_keyword=""
	echo -e "${CYAN}Enter playbook name:${CLEAR}"
	echo -e "${GREY}Partial match is supported${CLEAR}"
	echo -e "${GREY}Leave empty to list available playbooks${CLEAR}"
	read -p ">> " playbook_keyword

	local playbook_paths
	mapfile -t playbook_paths < <(find "${ANSIBLE_REPO_PATH}/playbooks" -maxdepth 1 -mindepth 1 -type f -not -name '.*' -name "*${playbook_keyword}*.yml")

	if [[ ${#playbook_paths[@]} -eq 0 ]]; then
		echo "ERROR: No playbook not found matching ${playbook_keyword}"
		echo -e "${CYAN}Enter path${CLEAR}"
		read -p ">> " ANSIBLE_PLAYBOOK_PATH
	elif [[ ${#playbook_paths[@]} -eq 1 ]]; then
		ANSIBLE_PLAYBOOK_PATH="${playbook_paths[0]}"
	else
		# menu
		while true; do
			for i in "${!playbook_paths[@]}"; do
				local index=$((i + 1))
				echo -e "${index}) $(basename ${playbook_paths[${i}]})"
			done
			read -r -p ">> " choice

			local playbook_path=${playbook_paths[${choice}]}
			
			if [[ ${choice} =~ ^-?[0-9]+$ ]] && [[ -n ${playbook_path} ]]; then
				ANSIBLE_PLAYBOOK_PATH="${playbook_path}"
				break
			else
				echo
		 		echo -e "${MAGENTA}Invalid choice - try again.${CLEAR}"
		 		continue		
			fi
		done
	fi

	# restore trap
	if [[ -n "${old_trap}" ]]; then
		eval "${old_trap}"
	else
		trap - SIGINT
	fi

	if [[ ! -f "${ANSIBLE_PLAYBOOK_PATH}" ]]; then
		echo "Playbook path not found: ${ANSIBLE_PLAYBOOK_PATH}"
		return 1
	else
		echo "${ANSIBLE_PLAYBOOK_PATH}" > "${PATH_DATA_LAST_PLAYBOOK}"
		echo "-> ${ANSIBLE_PLAYBOOK_PATH}"
	fi
}