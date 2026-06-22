function debug { # $msg
	local msg="${1}"

	if ((DEBUG)); then
		echo -e "${msg}"
	fi
}