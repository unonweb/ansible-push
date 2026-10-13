# REQUIRES
# --------
# - ANSIBLE_INVENTORY_PATH
# - ANSIBLE_PLAYBOOK_PATH
# - ANSIBLE_PLAYBOOK_EXEC_PATH
# - PATH_DATA

# SETS
# ----
# - ANSIBLE_TAGS

# SAVES
# -----
# - out_path

function save_tag_list {

	local TAGS_AVAILABLE=()
	local out_name=$(basename ${ANSIBLE_PLAYBOOK_PATH})
	out_name="${out_name//.yml}" # remove .yml
	local out_path="${PATH_DATA}/tags.${out_name}"

	# Get available tags
	echo
	echo -e "Searching for tags associated with playbook $(basename ${ANSIBLE_PLAYBOOK_PATH}) ${BLINKING}...${CLEAR}"
	# Extracting TASK TAGS line
	local output_list_tags=$(${ANSIBLE_PLAYBOOK_EXEC_PATH} --list-tags --inventory "${ANSIBLE_INVENTORY_PATH}" "${ANSIBLE_PLAYBOOK_PATH}")
	# Removing the prefix and brackets
	task_tags_line="${output_list_tags#*TASK TAGS: }" # Remove from the beginning until TASK TAGS: 
	task_tags_line="${task_tags_line//[\[\]]/}" # Remove brackets
	# Converting the string into an array using IFS
	IFS=', ' read -r -a TAGS_AVAILABLE <<< "${task_tags_line}"

	if [[ ${#TAGS_AVAILABLE[@]} -eq 0 ]]; then
		echo "ERROR: Could not find any tags with playbook: ${ANSIBLE_PLAYBOOK_PATH} and inventory: ${ANSIBLE_INVENTORY_PATH}"
		exit 1
	else
		printf "%s\n" "${TAGS_AVAILABLE[@]}" > ${out_path}
		echo "Tag list saved to: ${out_path}"
	fi
}