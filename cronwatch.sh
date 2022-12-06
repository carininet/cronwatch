#!/bin/bash

## 
## Notify system administrator that crontab has been running for too long
##

# Script selfie
SCRIPT=$(readlink -nf "${0}")
HOMEDIR=$(dirname "${SCRIPT}")
MYSELF=$(basename "${SCRIPT}" ".${SCRIPT##*.}")
MYNODE=$(hostname -f)

# Constants
PSREX='([0-9]+)\s+([0-9]+)\s+(\w+\s+\w+\s+[0-9]+\s+[0-9]+:[0-9]+:[0-9]+\s+[0-9]+)\s+(.+)'
TIMEOUT=120
SENDTO='sysadmin@example.com'

# Get cron processes
res=0
npid=0
cron=$(ps -o pid,ppid,lstart,cmd -C 'cron')
while read process; do
	if [[ ${process} =~ ${PSREX} ]]; then
		pid[$npid]="${BASH_REMATCH[1]}"
		ppid[$npid]="${BASH_REMATCH[2]}"
		lstart[$npid]="${BASH_REMATCH[3]}"
		cmd[$npid]="${BASH_REMATCH[4]}"

		# Exclude main crontab process
		if [[ ${ppid[$npid]} > 1 ]]; then
			# Get process duration (minutes)
			running=$(($(($(date +%s) - $(date -d "${lstart}" +%s))) / 60))
			if [[ $running > $TIMEOUT ]]; then
				# Log to rsyslog and send warning mail
				subject="${MYNODE} crontab is running for ${running} minutes"
				message="${MYSELF}@${MYNODE}: Found stuck crontab pid=${pid[$npid]}, ppid=${ppid[$npid]}"
				logger -p local3.warning "${message}"
				mail -s "${subject}" "${SENDTO}" <<< "${message}"
				res=1
			fi
		fi

		npid=$((npid+1))
	fi
done <<< "${cron}"

exit $res
