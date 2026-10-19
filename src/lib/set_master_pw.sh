# REQUIRES
# --------
# - MASTER_PW_FILE

# SETS
# --------
# - ANSIBLE_RAND_HEX

function set_master_pw {

	# Trap SIGINT (CTRL+C)
	local old_trap=$(trap -p SIGINT)
    trap 'return 0' SIGINT

	if ((!VAULTS_USE_MASTER_PW_FOR_VAULT_PW_LOOKUP)); then
		echo "No master pw"
		return 0
	fi

	if [[ -z "${MASTER_PW_FILE}" ]]; then
		echo "ERROR: Missing required arg: MASTER_PW_FILE"
		return 1
	fi
	
	# Prompt for master password interactively if not already cached in RAM
	if [ ! -f "${MASTER_PW_FILE}" ]; then

		local master_pw
		read -rs -p "Enter Master Password: " master_pw

		# generate a random seed
		ANSIBLE_RAND_HEX=$(openssl rand -hex 32)
		# encrypt plain-text password file using the seed
		printf "%s" "${master_pw}" | openssl enc -aes-256-cbc -pbkdf2 -salt -out "${MASTER_PW_FILE}" -pass pass:"${ANSIBLE_RAND_HEX}"
		chmod 600 "${MASTER_PW_FILE}"
	fi

	# restore trap
	if [[ -n "${old_trap}" ]]; then
		eval "${old_trap}"
	else
		trap - SIGINT
	fi
}
