function menu_tags {

	local options=(
		"Set"
		"Add"
		"Refresh List"
		"Return"
	)

	local default_choice=1
	local choice
	local rc

	echo -e "${UNDERLINE}Edit Tags${CLEAR}"
	for i in "${!options[@]}"; do
		local index=$((i + 1))
		if [[ ${index} -eq ${default_choice} ]]; then
			#printf "%d) %s [default]\n" "${index}" "${options[${i}]}"
			echo -e "${BOLD}${index}) ${options[${i}]}${CLEAR}"
		else
			# printf "%d) %s\n" "${index}" "${options[${i}]}"
			echo -e "${index}) ${options[${i}]}"
		fi
	done

	read -r -p ">> " choice
	
	# If user pressed Enter, use the default
	choice="${choice:-${default_choice}}"

	case "${choice}" in
		1)
			# Set
			set_tags && rc=0
			;;
		2)
			# Add
			set_tags --add  && rc=0
			;;
		3)
			# Refresh List
			save_tag_list && rc=0
			;;
		4)
			# Return
			rc=0
			;;
	esac

	return ${rc}
}