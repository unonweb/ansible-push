function _save_ansible_cfg {
        
    local new_content=""
    local in_list=0
    local list_written=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "${line}" =~ ^\[ ]]; then
            if (( in_list && !list_written )); then
                for k in "${VAULT_MAP_KEYS_ARRAY[@]}"; do
                    local entry_str
                    printf -v entry_str "    %s@%s,\n" "$k" "${VAULT_MAP_ID_TO_METHOD[$k]}"
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
                    for k in "${VAULT_MAP_KEYS_ARRAY[@]}"; do
                        local entry_str
                        printf -v entry_str "    %s@%s,\n" "$k" "${VAULT_MAP_ID_TO_METHOD[$k]}"
                        new_content+="${entry_str}"
                    done
                    list_written=1
                fi
                in_list=0
            fi
        fi

        if [[ "${line}" =~ ^vault_identity_list[[:space:]]*= ]]; then
            new_content+="vault_identity_list ="$'\n'
            for k in "${VAULT_MAP_KEYS_ARRAY[@]}"; do
                local entry_str
                printf -v entry_str "    %s@%s,\n" "$k" "${VAULT_MAP_ID_TO_METHOD[$k]}"
                new_content+="${entry_str}"
            done
            in_list=1
            list_written=1
            continue
        fi

        new_content+="${line}"$'\n'
    done < "${ANSIBLE_CONFIG_PATH}"

    if (( in_list && !list_written )); then
        for k in "${VAULT_MAP_KEYS_ARRAY[@]}"; do
            local entry_str
            printf -v entry_str "    %s@%s,\n" "$k" "${VAULT_MAP_ID_TO_METHOD[$k]}"
            new_content+="${entry_str}"
        done
    fi

    # Write the accumulated content directly back to the config file
    printf '%s' "${new_content}" > "${ANSIBLE_CONFIG_PATH}"
    echo
	echo "Successfully updated ${ANSIBLE_CONFIG_PATH}"
    return 0
}

function _parse_ansible_config_set_vault_map {
	
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
                    VAULT_MAP_ID_TO_METHOD["${k}"]="${v}"
                    VAULT_MAP_KEYS_ARRAY+=("${k}")
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
                    VAULT_MAP_ID_TO_METHOD["${k}"]="${v}"
                    VAULT_MAP_KEYS_ARRAY+=("${k}")
                fi
            fi
        fi
    done < "${ANSIBLE_CONFIG_PATH}"

	if [[ ${#VAULT_MAP_KEYS_ARRAY[@]} -eq 0 ]]; then
		echo
        echo "ERROR: No vault identities found in ${ANSIBLE_CONFIG_PATH}."
        return 1
    fi
}