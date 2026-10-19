# REQUIRES
# --------
# - MASTER_PW_FILE

function set_master_pw {

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
		echo ""
		#echo -n "${master_pw}" > "${MASTER_PW_FILE}"
		echo "Enter a PIN to protect it: "
		echo "(This will be asked every time you run Ansible)"
		local user_pin
		read -p ">> " -s user_pin
		echo
		echo -n "${master_pw}" | openssl enc -aes-256-cbc -salt -pbkdf2 -base64 -pass pass:"${user_pin}" > "${MASTER_PW_FILE}"
		chmod 600 "${MASTER_PW_FILE}"
	fi
}
