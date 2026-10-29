function _set_vault_method { # ${id_selected}

	# REQUIRES
	# --------
	# - VAULT_MAP_ID_TO_METHOD
	
	local id_selected="${1}"

	# Scan for executable scripts in PATH_RUN
	local lookup_scripts=()
	for script in "${PATH_RUN}"/*; do
		[[ -f "${script}" && -x "${script}" ]] && lookup_scripts+=("${script}")
	done

	if [[ ${#lookup_scripts[@]} -eq 0 ]]; then
		echo "Error: No executable lookup_scripts found in ${PATH_RUN}" >&2
		return 1
	fi
	
	# prompt
	echo
	if [[ "${id_selected}" == "all" ]]; then
		echo -e "${CYAN}Lookup method for all vault ids:${CLEAR}"
	else
		echo -e "${CYAN}Lookup method for '${id_selected}':${CLEAR}"
	fi
	# menu
	local options=(
		prompt 
		${lookup_scripts[@]}
	)

	for i in "${!options[@]}"; do
		local index=$((i + 1))
		echo -e "${index}) $(basename ${options[${i}]})"
	done
	read -p ">> " input_lookup_method
	local vault_method_selected="${options[$((input_lookup_method-1))]}"
	
	if [[ "${id_selected}" == "all" ]]; then
		# set method for all
		for key in ${!VAULT_MAP_ID_TO_METHOD[@]}; do 
			VAULT_MAP_ID_TO_METHOD["${key}"]="${vault_method_selected}"
		done
	else
		# set method for one
		VAULT_MAP_ID_TO_METHOD["${id_selected}"]="${vault_method_selected}"
	fi
}

# REQUIRES
# --------
# - PATH_STATE_VAULT_MAP

# SETS
# ----
# - VAULT_MAP_ID_TO_METHOD

function map_vault_id_to_method { #${vault_ids[@]}

	# args
	local vault_ids=(${@})
	local rc
	
	# checks
    if [[ ${#vault_ids[@]} -eq 0 ]]; then
        echo "Error: No vault ids provided" >&2
        return 1
    fi

	if [[ -z ${PATH_STATE_VAULT_MAP} ]]; then
        echo "Error: Var not set: PATH_STATE_VAULT_MAP" >&2
        return 1
    fi

	# trap
	local old_trap=$(trap -p SIGINT)
    trap 'return 0' SIGINT

    declare -A VAULT_MAP_ID_TO_METHOD
	
	if [[ -f "${PATH_STATE_VAULT_MAP}" ]]; then
		source "${PATH_STATE_VAULT_MAP}"
	fi

	local method_default="prompt"
	for host in "${vault_ids[@]}"; do
		if [[ ! -v VAULT_MAP_ID_TO_METHOD["${host}"] ]]; then
			VAULT_MAP_ID_TO_METHOD["${host}"]="${method_default}"
		fi
	done
	
    # Menu
	while true; do
        echo
		echo -e "${CYAN}Select:${CLEAR}"
        local i=1
		local vault_map_keys=()
        for id in "${!VAULT_MAP_ID_TO_METHOD[@]}"; do
            echo -e "${i}) ${id}@${GREEN}${VAULT_MAP_ID_TO_METHOD[${id}]}${CLEAR}"
			vault_map_keys+=("${id}")
            ((i++))
        done
		echo "---"
		echo -e "a) All at once"
		echo -e "${BOLD}q) Quit${CLEAR}"
        read -p ">> " input

		# If user pressed Enter, use the default
		input="${input:-"q"}"

        if [[ "${input}" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#vault_map_keys[@]} )); then
			# Map the 1-based menu choice back to the 0-based keys array index
			input=$((input-1))
    		vault_id_selected="${vault_map_keys[${input}]}"
			_set_vault_method "${vault_id_selected}" && rc=0
		elif [[ "${input}" == "a" ]]; then
			_set_vault_method "all" && rc=0
		elif [[ "${input}" == "q" ]]; then
			rc=0
			break
		else
			echo "Invalid selection: ${input}"
		fi
    done

	# Export the array definition to a file
	declare -p VAULT_MAP_ID_TO_METHOD > "${PATH_STATE_VAULT_MAP}"

	# restore trap
	if [[ -n "${old_trap}" ]]; then
		eval "${old_trap}"
	else
		trap - SIGINT
	fi

	return ${rc}
}