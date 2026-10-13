# REQUIRES
# --------
# - ANSIBLE_REPO_PATH
# - PATH_DATA_LAST_PLAYBOOK

# SETS
# ----
# - ANSIBLE_PLAYBOOK_PATH

function set_playbook_path {

	# ask user
	local playbook_keyword=""
	echo
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
		select playbook_path in "${playbook_paths[@]}"; do
			if [ -n "${playbook_path}" ]; then
				ANSIBLE_PLAYBOOK_PATH="${playbook_path}"
				break
			else
				echo -e "${MAGENTA}Invalid choice - try again.${CLEAR}"
				continue
			fi
		done
	fi

	if [[ ! -f "${ANSIBLE_PLAYBOOK_PATH}" ]]; then
		echo "Playbook path not found: ${ANSIBLE_PLAYBOOK_PATH}"
		return 1
	else
		echo "${ANSIBLE_PLAYBOOK_PATH}" > "${PATH_DATA_LAST_PLAYBOOK}"
		echo "-> ${ANSIBLE_PLAYBOOK_PATH}"
	fi
}