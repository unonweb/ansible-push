# NOTES
# =====
# 0: Emergency, 1: Alert, 2: Critical, 3: Error, 4: Warning, 5: Notice, 6: Info, 7: Debug

# SUGGESTS
# ========
# - LOG_LVL

function log {

    local message="${1}" # optionally includes a lvl like <3>
	local log_lvl=${LOG_LVL:3}
	local msg_lvl
	local msg_only
	local include_lvl_prefix=1 # turn off when debugging

	# Regex pattern that captures two groups:
	# <number>
	# message
    if [[ "${message}" =~ ^\<([0-7])\>[[:space:]]*(.*) ]]; then
        msg_lvl="${BASH_REMATCH[1]}"
        msg_only="${BASH_REMATCH[2]}"
	else
    	msg_lvl="" # Optional: or set a default level like "6" (info) or "3" (err)
    	msg_only="${message}"
	fi

	# Check msg_lvl
	# If not specified default to log, too
	if [[ -z "${msg_lvl}" || "${msg_lvl}" -le ${log_lvl} ]]; then

		# Log to console
		# Replace all newlines with a space
		message="${message//\\n/ }"
		msg_only="${msg_only//\\n/ }"
		# Remove space after "<num> "
		message="${message/> />}"
		msg_only="${msg_only/> />}"
		
		if (( include_lvl_prefix )); then
			# Use this when connected to systemd journal
			# Log original message
			echo -e "${message}"
		else
			# No systemd service around
			# Log clean message
			echo -e "${msg_only}"
		fi
	fi
}