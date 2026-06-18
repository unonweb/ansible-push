function set_playbook {
	# requires: 
	# - ANSIBLE_REPO_PATH
	# - ANSIBLE_HOST
	# sets:
	# - ANSIBLE_PLAYBOOK_PATH

	local playbook_paths
	mapfile -t playbook_paths < <(find ${ANSIBLE_REPO_PATH}/playbooks -maxdepth 1 -mindepth 1 -type f -name "*${ANSIBLE_HOST}*")

	echo
	echo "Trying to find playbook for ${ANSIBLE_HOST} ..."

	if [[ ${#playbook_paths[@]} -eq 0 ]]; then
		echo "ERROR: No playbook not found for ${ANSIBLE_HOST}"
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
		echo "-> ${ANSIBLE_PLAYBOOK_PATH}"
	fi
}