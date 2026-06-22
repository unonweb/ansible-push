function debug { # $msg
	local msg="${1}"

	if ((DEBUG)); then
		echo -e "[$(date "+%Y-%m-%d %H:%M:%S")] ${msg}" >> "${LOG_FILE}"
	fi
}