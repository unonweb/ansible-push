# REQUIRES
# --------
# - ANSIBLE_INVENTORY_PATH
# - ANSIBLE_PLAYBOOK_PATH
# - ANSIBLE_PLAYBOOK_EXEC_PATH
# - PATH_STATE

# SETS
# ----
# - ANSIBLE_TAGS

# WRITES TO
# ---------
# - out_path

function save_tag_list {

	local tags_available=()
	local out_name=$(basename ${ANSIBLE_PLAYBOOK_PATH//.yml})
	local out_path="${PATH_STATE}/tags.${out_name}"

	# Get available tags
	echo
	echo -e "Searching for tags associated with playbook $(basename ${ANSIBLE_PLAYBOOK_PATH}) ${BLINKING}...${CLEAR}"
	
	# Get the playbook tags output
	local output_list_tags=$(${ANSIBLE_PLAYBOOK_EXEC_PATH} --list-tags --inventory "${ANSIBLE_INVENTORY_PATH}" "${ANSIBLE_PLAYBOOK_PATH}")
	declare -A unique_tags=()
	# Define the regex pattern in a variable to avoid syntax errors
	local regex='TASK TAGS:[[:space:]]*\[(.*)\]'

	# Process the output line by line
	while IFS= read -r line; do
		# Check if the line contains TASK TAGS and capture the content inside the brackets
		if [[ "${line}" =~ ${regex} ]]; then
			local tags_str="${BASH_REMATCH[1]}"
			
			# Split the comma-separated tags into an array
			IFS=',' read -ra split_tags <<< "$tags_str"
			
			for tag in "${split_tags[@]}"; do
				# Trim leading/trailing whitespace
				tag="${tag#"${tag%%[![:space:]]*}"}"
				tag="${tag%"${tag##*[![:space:]]}"}"
				
				# Add to associative array to deduplicate
				[[ -n "${tag}" ]] && unique_tags["${tag}"]=1
			done
		fi
	done <<< "${output_list_tags}"

	# Convert the unique keys back into an indexed array
	local tags_available=("${!unique_tags[@]}")

	if [[ ${#tags_available[@]} -eq 0 ]]; then
		echo "ERROR: Could not find any tags with playbook: ${ANSIBLE_PLAYBOOK_PATH} and inventory: ${ANSIBLE_INVENTORY_PATH}"
		return 1
	else
		mapfile -t tags_available_sorted < <(printf '%s\n' "${tags_available[@]}" | sort)
		printf "%s\n" "${tags_available_sorted[@]}" > ${out_path}
		echo "Tag list saved to: ${out_path}"
		echo
		return 0
	fi
}