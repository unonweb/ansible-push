# REQUIRES
# --------
# - ANSIBLE_CONFIG_PATH

function _save_ansible_cfg {
        
    local new_content=""
    local in_list=0
    local list_written=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "${line}" =~ ^\[ ]]; then
            if (( in_list && !list_written )); then
                for k in "${VAULT_ID_MAP_KEYS[@]}"; do
                    local entry_str
                    printf -v entry_str "    %s@%s,\n" "$k" "${VAULT_ID_MAP[$k]}"
                    new_content+="${entry_str}"
                done
                list_written=1
            fi
            in_list=0
        elif (( in_list )); then
            if [[ "${line}" =~ ^[[:space:]] && -n "${line//[[:space:]]/}" ]]; then
                continue # Skip old entries
            else
                if ! (( list_written )); then
                    for k in "${VAULT_ID_MAP_KEYS[@]}"; do
                        local entry_str
                        printf -v entry_str "    %s@%s,\n" "$k" "${VAULT_ID_MAP[$k]}"
                        new_content+="${entry_str}"
                    done
                    list_written=1
                fi
                in_list=0
            fi
        fi

        if [[ "${line}" =~ ^vault_identity_list[[:space:]]*= ]]; then
            new_content+="vault_identity_list ="$'\n'
            for k in "${VAULT_ID_MAP_KEYS[@]}"; do
                local entry_str
                printf -v entry_str "    %s@%s,\n" "$k" "${VAULT_ID_MAP[$k]}"
                new_content+="${entry_str}"
            done
            in_list=1
            list_written=1
            continue
        fi

        new_content+="${line}"$'\n'
    done < "${ANSIBLE_CONFIG_PATH}"

    if (( in_list && !list_written )); then
        for k in "${VAULT_ID_MAP_KEYS[@]}"; do
            local entry_str
            printf -v entry_str "    %s@%s,\n" "$k" "${VAULT_ID_MAP[$k]}"
            new_content+="${entry_str}"
        done
    fi

    # Write the accumulated content directly back to the config file
    printf '%s' "${new_content}" > "${ANSIBLE_CONFIG_PATH}"
    echo
	echo "Successfully updated ${ANSIBLE_CONFIG_PATH}"
    return 0
}

function _set_vault_method {
	
	local mode
	if [[ "${1}" == "--all" ]]; then
		mode="all"
	fi

	# Scan for executable scripts in PATH_RUN
	local scripts=()
	for script in "${PATH_RUN}"/*; do
		[[ -f "${script}" && -x "${script}" ]] && scripts+=("${script}")
	done

	if [[ ${#scripts[@]} -eq 0 ]]; then
		echo "Error: No executable scripts found in ${PATH_RUN}" >&2
	fi
	
	local options=(prompt ${scripts[@]})
	echo
	if [[ "${mode}" == "all" ]]; then
		echo -e "${CYAN}Select lookup method for 'all':${CLEAR}"
	else
		echo -e "${CYAN}Select lookup method for '${VAULT_ID_SELECTED}':${CLEAR}"
	fi
	for i in "${!options[@]}"; do
		local index=$((i + 1))
		echo -e "${index}) $(basename ${options[${i}]})"
	done
	read -p ">> " input_lookup_method
	local vault_method_selected="${options[$((input_lookup_method-1))]}"
	
	if [[ "${mode}" == "all" ]]; then
		for key in ${!VAULT_ID_MAP[@]}; do 
			VAULT_ID_MAP["${key}"]="${vault_method_selected}"
		done
	else
		VAULT_ID_MAP["${VAULT_ID_SELECTED}"]="${vault_method_selected}"
	fi
}

function _set_vault_map {
	
	local reading_vault=0

    while IFS= read -r line || [[ -n "${line}" ]]; do
        local trimmed="${line#"${line%%[![:space:]]*}"}" # left trim
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"   # right trim

        # Stop reading if we hit a new section header
        if [[ "${line}" =~ ^\[ ]]; then
            reading_vault=0
        elif (( reading_vault )); then
            if [[ "${line}" =~ ^[[:space:]] && -n "${trimmed}" ]]; then
                local entry="${trimmed%,}" # strip trailing comma
                if [[ "${entry}" == *@* ]]; then
                    local k="${entry%%@*}"
                    local v="${entry#*@}"
                    VAULT_ID_MAP["${k}"]="${v}"
                    VAULT_ID_MAP_KEYS+=("${k}")
                fi
            else
                reading_vault=0
            fi
        fi

        # Detect start of vault_identity_list
        if [[ "${line}" =~ ^vault_identity_list[[:space:]]*= ]]; then
            reading_vault=1
            # Check if there's an inline value on the same line
            local rhs="${line#*=}"
            rhs="${rhs#"${rhs%%[![:space:]]*}"}"
            rhs="${rhs%"${rhs##*[![:space:]]}"}"
            if [[ -n "$rhs" ]]; then
                local entry="${rhs%,}"
                if [[ "${entry}" == *@* ]]; then
                    local k="${entry%%@*}"
                    local v="${entry#*@}"
                    VAULT_ID_MAP["${k}"]="${v}"
                    VAULT_ID_MAP_KEYS+=("${k}")
                fi
            fi
        fi
    done < "${ANSIBLE_CONFIG_PATH}"

	if [[ ${#VAULT_ID_MAP_KEYS[@]} -eq 0 ]]; then
        echo "No vault identities found in ${ANSIBLE_CONFIG_PATH}."
        return 1
    fi
}

function manage_vault_ids {

    if [[ ! -f "${ANSIBLE_CONFIG_PATH}" ]]; then
        echo "Error: Configuration file '${ANSIBLE_CONFIG_PATH}' not found." >&2
        return 1
    fi

	local rc

	# Trap SIGINT (CTRL+C)
	local old_trap=$(trap -p SIGINT)
    trap 'return 0' SIGINT

    declare -A VAULT_ID_MAP
	declare -a VAULT_ID_MAP_KEYS

    _set_vault_map

    # Menu
    while true; do
        echo
		echo -e "${CYAN}Select:${CLEAR}"
        local i=1
        for vault_id in "${VAULT_ID_MAP_KEYS[@]}"; do
            echo -e "${i}) ${vault_id}@${GREEN}${VAULT_ID_MAP[${vault_id}]}${CLEAR}"
            ((i++))
        done
		echo "---"
		echo -e "a) Set all at once"
		echo -e "s) Save settings to ansible.cfg"
		echo -e "q) Quit"
        read -p ">> " input_main_menu
		
		# ANSIBLE_VAULT_IDENTITY_LIST

        if [[ "${input_main_menu}" =~ ^[0-9]+$ ]] && (( input_main_menu >= 1 && input_main_menu <= ${#VAULT_ID_MAP_KEYS[@]} )); then
			# Map the 1-based menu choice back to the 0-based keys array index
    		VAULT_ID_SELECTED="${VAULT_ID_MAP_KEYS[$((input_main_menu-1))]}"
			_set_vault_method
		elif [[ "${input_main_menu}" == "a" ]]; then
			_set_vault_method --all
		elif [[ "${input_main_menu}" == "s" ]]; then
			_save_ansible_cfg
		elif [[ "${input_main_menu}" == "q" ]]; then
			rc=0
			break
		else
			echo "Invalid selection."
		fi
    done

	# restore trap
	if [[ -n "${old_trap}" ]]; then
		eval "${old_trap}"
	else
		trap - SIGINT
	fi

	return ${rc}
}