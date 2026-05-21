function set_tags {
	# requires: 
	# - ANSIBLE_INVENTORY_PATH
	# - ANSIBLE_PLAYBOOK_PATH
	# - PATH_DATA
	# sets:
	# - ANSIBLE_TAGS

	local tags_query
	local available_tags=()
	local out_name=$(basename ${ANSIBLE_PLAYBOOK_PATH})
	out_name="${out_name//.yml}" # remove .yml
	local out_path="${PATH_DATA}/tags.${out_name}"
	local run_tag_extraction=true

	# Check if the output file already exists
    if [[ -f "${out_path}" ]]; then
		echo
		echo "Tag list found: ${out_path}"
		echo -e "${CYAN}Use this tag list?${CLEAR} (Enter)"
		echo -e "${CYAN}Refresh tag list?${CLEAR} (r)"
        read -p ">> " choice
        case "${choice}" in
            r)
				run_tag_extraction=true;;
            *) 
				run_tag_extraction=false;;
        esac
    fi

	# run_tag_extraction
	if [[ "${run_tag_extraction}" == true ]]; then
		# get available tags
		echo
		echo -e "${BLINKINK}Searching for tags associated with playbook ...${CLEAR}"
		# Extracting TASK TAGS line
		local output_list_tags=$(${ANSIBLE_PLAYBOOK_EXEC} --list-tags --inventory "${ANSIBLE_INVENTORY_PATH}" "${ANSIBLE_PLAYBOOK_PATH}")
		# Removing the prefix and brackets
		task_tags_line="${output_list_tags#*TASK TAGS: }" # Remove from the beginning until TASK TAGS: 
		task_tags_line="${task_tags_line//[\[\]]/}" # Remove brackets
		# Converting the string into an array using IFS
		IFS=', ' read -r -a available_tags <<< "${task_tags_line}"

		if [[ ${#available_tags[@]} -eq 0 ]]; then
			echo "ERROR: Could not find any tags with playbook: ${ANSIBLE_PLAYBOOK_PATH} and inventory: ${ANSIBLE_INVENTORY_PATH}"
			exit 1
		else
			printf "%s\n" "${available_tags[@]}" > ${out_path}
			echo "Tag list saved to: ${out_path}"
		fi
	else
		readarray -t available_tags < "${out_path}"
        echo "Loaded ${#available_tags[@]} unique tags from file"
	fi

	# ask user
	echo
	echo -e "${CYAN}Enter tags${CLEAR}"
	echo -e "${GREY}Separator: comma${CLEAR}"
	echo -e "${GREY}Partial match is supported${CLEAR}"
	echo -e "${GREY}Leave empty to list available hosts${CLEAR}"
	read -p ">> " tags_query

	# user inputs nothing
	if [[ -z "${tags_query}" ]]; then
		# show full list
		select tag in "${available_tags[@]}"; do
			if [ -n "${tag}" ]; then
				ANSIBLE_TAGS="${tag}"
				echo "-> ${tag}"
				break
			else
				echo -e "${MAGENTA}Invalid choice – try again.${CLEAR}"
				continue
			fi
		done
	else
		if [[ "${tags_query}" == "all" ]]; then
			ANSIBLE_TAGS="all"
			return 0
		fi
		
		# query
		tags_query=${tags_query,,} # make lowercase
		# Convert the comma-separated string into an array
		local tags_query_array=()
		local matches=()
		local no_matches=()
		IFS=',' read -ra tags_query_array <<< "${tags_query}"

		# Iterate through each tag in the query
		# find matches
		for query_tag in "${tags_query_array[@]}"; do
			local this_query_matches=()
			for tag in "${available_tags[@]}"; do
				tag=${tag,,} # lowercase
				if [[ ${tag} == *"${query_tag}"* ]]; then
					this_query_matches+=("${tag}")
				fi
			done
			if [[ ${#this_query_matches[@]} -eq 1 ]]; then
				matches+=("${this_query_matches[0]}")
				echo "-> ${this_query_matches[0]}"
			else
				echo
				echo -e "${CYAN}Multiple matches found for ${query_tag}. Select:${CLEAR}"
				select choice in "${this_query_matches[@]}"; do
					if [[ -z ${choice} ]]; then
						echo -e "${MAGENTA}Invalid choice – try again.${CLEAR}"
						continue
					else
						matches+=("${choice}")
						echo "-> ${choice}"
						break
					fi
				done
			fi
		done

		if [[ ${#matches[@]} -eq 0 ]]; then
			# no match
			echo -e "${MAGENTA}Could not find any matches. Please try again.${CLEAR}"
			# repeat
			set_tags
		else
			echo
			echo -e "${CYAN}Use the following tags?${CLEAR} ${GREY}${matches[@]}${CLEAR} (enter | any)"
			read -p ">> " confirm
			if [[ -z ${confirm} ]]; then
				joined=$(printf '%s,' "${matches[@]}")
				joined=${joined%,}   # strip the trailing comma
				ANSIBLE_TAGS="${joined}"
			else
				echo -e "Restart."
				# repeat
				set_tags
			fi
		fi
	fi

	if [[ -n ${ANSIBLE_TAGS} ]]; then
		return 0
	else
		echo "ERROR: ANSIBLE_TAGS not set!"
		return 1
	fi
}