# REQUIRES
# --------
# - ANSIBLE_PLAYBOOK_PATH
# - ANSIBLE_REPO_PATH

function menu_lint {

	local ansible_lint_config_path="${ANSIBLE_REPO_PATH}/.ansible-lint.yml"
	local profiles=(
		"min" 
		"basic"
		"moderate"
		"safety"
		"shared"
		"production"
	)
	local default_choice=2
	local choice

	if ! which ansible-lint &> /dev/null; then
		echo "ERROR: ansible-lint cmd not found. Install into 'ansible' venv with:"
		echo "pipx inject --force --include-apps ansible ansible-lint"
		return 1
	fi

	# trap
	local old_trap=$(trap -p SIGINT)
    trap 'return 0' SIGINT

	if [[ ! -f "${ansible_lint_config_path}" ]]; then
		echo "WARN: File does not exist: ${ansible_lint_config_path}"
		return 1
	fi

	# menu
	echo -e "${GREY}Config: ${ansible_lint_config_path}${CLEAR}"
	echo
	echo -e "${UNDERLINE}Choose Profile${CLEAR}"
	for i in "${!profiles[@]}"; do
		local index=$((i + 1))
		if [[ ${index} -eq ${default_choice} ]]; then
			echo -e "${BOLD}${index}) ${profiles[${i}]}${CLEAR}"
		else
			echo -e "${index}) ${profiles[${i}]}"
		fi
	done

	read -r -p ">> " choice
	
	# If user pressed Enter, use the default
	choice="${choice:-${default_choice}}"

	local profile=${profiles[${choice}]}

	ansible-lint --config-file "${ansible_lint_config_path}" --profile=${profile} --force-color --fix=yaml "${ANSIBLE_PLAYBOOK_PATH}"

	# restore trap
	if [[ -n "${old_trap}" ]]; then
		eval "${old_trap}"
	else
		trap - SIGINT
	fi
}