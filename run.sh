#!/bin/bash

ESC=$(printf "\e")
BOLD="${ESC}[1m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RESET="${ESC}[0m"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
EXEC_PATH="${SCRIPT_DIR}/src/main.sh"

echo -e "Use ${BOLD}ctrl + c${RESET} to exit."
while true; do
	echo "---"
	source ${EXEC_PATH}
	exit_code=${?}  # Store the exit code immediately
	if [[ ${exit_code} -ne 0 ]]; then
		echo -e "${MAGENTA}Script returned error code: ${exit_code}${RESET}"
		echo
		read -p "Press Enter to exit ..."
		break
	fi
done