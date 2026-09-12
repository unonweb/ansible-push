# REQUIRES
# --------
# - ANSIBLE_REPO_PATH
# - ANSIBLE_HOST
# - VAULT_MAP

function add_vault {

	local scope="${1:-"host"}"
	
	shopt -s nullglob

	# interactive mode		
	case "${scope}" in

		"host")
			echo
			echo -e "${CYAN}Select vault-id from host_vars:${CLEAR}"
			select host in "${HOST_VAR_DIRS[@]}"; do
				if [[ -z ${host} ]]; then
					echo -e "${MAGENTA}Invalid selection - try again.${CLEAR}"
					continue
				else
					add_vault_flag "${host}"
					break
				fi
			done
			;;

		"group")
			echo
			echo -e "${CYAN}Select vault-id from group_vars:${CLEAR}"
			select group in "${GROUP_VAR_DIRS[@]}"; do
				if [[ -z ${group} ]]; then
					echo -e "${MAGENTA}Invalid selection - try again.${CLEAR}"
					continue
				else
					add_vault_flag "${group}"
					break
				fi
			done
			;;
	esac
}