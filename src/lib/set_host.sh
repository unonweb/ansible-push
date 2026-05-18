function set_host {
	# requires: 
	# - ANSIBLE_INVENTORY_PATH
	# sets:
	# - ANSIBLE_HOST

	local host_query
	local available_hosts

	while IFS= read -r line; do
		# remove leading whitespace characters
		line="${line#"${line%%[![:space:]]*}"}"
		# remove trailing whitespace characters
		line="${line%"${line##*[![:space:]]}"}"
		if [[ ${line} != hosts* && -n ${line} ]]; then
			available_hosts+=("${line}")
		fi
	done < <(${ANSIBLE_EXEC} all --inventory=${ANSIBLE_INVENTORY_PATH} --list-hosts)

	if [[ ${#available_hosts[@]} -eq 0 ]]; then
		echo "ERROR: Could not find any hosts in inventory file: ${ANSIBLE_INVENTORY_PATH}"
		exit 1
	fi

	# ask user
	echo
	echo -e "${CYAN}Enter host name${CLEAR}"
	echo -e "${GREY}Partial match is supported${CLEAR}"
	echo -e "${GREY}Leave empty to list available hosts${CLEAR}"
	read -p ">> " host_query
	shopt -s nocasematch # make [[ string == pattern ]] case‑insensitive

	if [[ -z ${host_query} ]]; then
		# empty query
		select choice in "${available_hosts[@]}"; do
			if [[ -z ${choice} ]]; then
				echo -e "${MAGENTA}Invalid choice – try again.${CLEAR}"
				continue
			else
				ANSIBLE_HOST="${choice}"
				echo "-> ${ANSIBLE_HOST}"
				break
			fi
		done
	else
		# query
		host_query=${host_query,,} # make lowercase

		# find matches
		local matches=()
		for host in "${available_hosts[@]}"; do
			host=${host,,} # lowercase
			if [[ ${host} == *"${host_query}"* ]]; then
				matches+=("${host}")
			fi
		done

		if [[ ${#matches[@]} -eq 0 ]]; then
			# no match
			echo -e "${MAGENTA}Could not find any matches. Please try again.${CLEAR}"
			# repeat
			set_host
		elif [[ ${#matches[@]} -eq 1 ]]; then
			# one match
			ANSIBLE_HOST="${matches[0]}"
			echo "-> ${ANSIBLE_HOST}"
		else
			# more matches
			select choice in "${matches[@]}"; do
				if [[ -z ${choice} ]]; then
					echo -e "${MAGENTA}Invalid choice – try again.${CLEAR}"
					continue
				else
					ANSIBLE_HOST="${choice}"
					echo "-> ${ANSIBLE_HOST}"
					break
				fi
			done
		fi
	fi

	if [[ -n ${ANSIBLE_HOST} ]]; then
		return 0
	else
		echo "ERROR: ANSIBLE_HOST not set!"
		return 1
	fi
}