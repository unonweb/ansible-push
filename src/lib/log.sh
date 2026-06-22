function log { # $msg
	local msg="${1}"

	if ((LOG)); then
		if [[ -z ${LOG_FILE} ]]; then
			echo "ERROR: LOG_FILE not specified!"
			return 1
		fi
		echo -e "[$(date "+%Y-%m-%d %H:%M:%S")] ${msg}" >> "${LOG_FILE}"
	fi
}