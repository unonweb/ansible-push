# REQUIRES
# --------
# - ANSIBLE_INVENTORY_PATH
# - ANSIBLE_PLAYBOOK_PATH
# - ANSIBLE_PLAYBOOK_EXEC_PATH
# - PATH_DATA
# - save_tag_list

# SETS
# ----
# - ANSIBLE_TAGS

function set_tags {

	local tags_query
	local TAGS_AVAILABLE=()
	local out_name=$(basename ${ANSIBLE_PLAYBOOK_PATH})
	out_name="${out_name//.yml}" # remove .yml
	local out_path="${PATH_DATA}/tags.${out_name}"
	local run_tag_extraction=true

	local old_trap=$(trap -p SIGINT)

    # Trap SIGINT (CTRL+C)
    trap 'return 0' SIGINT

	# Check if the output file already exists
    if [[ -f "${out_path}" ]]; then
		echo
		echo "Tag list found: ${out_path}"
	else
		save_tag_list
    fi

	readarray -t TAGS_AVAILABLE < "${out_path}"
	echo "Loaded ${#TAGS_AVAILABLE[@]} unique tags from file"

	# ask user
	echo
	echo -e "${CYAN}Enter tags:${CLEAR}"
	echo -e "${GREY}Separator: comma${CLEAR}"
	echo -e "${GREY}Partial match is supported${CLEAR}"
	echo -e "${GREY}Leave empty to list available tags${CLEAR}"
	read -p ">> " tags_query

	# user inputs nothing
	if [[ -z "${tags_query}" ]]; then
		# show full list
		select tag in "${TAGS_AVAILABLE[@]}"; do
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
			for tag in "${TAGS_AVAILABLE[@]}"; do
				tag=${tag,,} # lowercase
				if [[ ${tag} == *"${query_tag}"* ]]; then
					this_query_matches+=("${tag}")
				fi
			done

			# one match
			if [[ ${#this_query_matches[@]} -eq 0 ]]; then
				echo
				echo -e "${MAGENTA}'${query_tag}' not found among the following available tags:${CLEAR}\n${TAGS_AVAILABLE[@]}"
				continue
			elif [[ ${#this_query_matches[@]} -eq 1 ]]; then
				matches+=("${this_query_matches[0]}")
				echo "-> ${this_query_matches[0]}"
			else
				echo
				echo -e "${CYAN}Multiple matches found for '${query_tag}'. Select:${CLEAR}"
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
			echo -e "${CYAN}Use the following tags?${CLEAR} (enter | any)"
			printf -- '- %s\n' "${matches[@]}"
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

	# restore trap
	if [[ -n "${old_trap}" ]]; then
		eval "${old_trap}"
	else
		trap - SIGINT
	fi

	if [[ -n ${ANSIBLE_TAGS} ]]; then
		echo "${ANSIBLE_TAGS}" > "${PATH_DATA_LAST_TAGS}"
		return 0
	else
		echo "ERROR: ANSIBLE_TAGS not set!"
		return 1
	fi
}