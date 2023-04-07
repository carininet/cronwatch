#!/bin/bash

## 
## Notify system administrator that crontab or S3 backup has been running for too long
##


# -= Functions =-

# Convert a array to comma-separated string
function a2s
{
	local IFS=","
	a2sresult="${*}"
}

# Log and notify process identified by pid and parent
notify()
{
	# Build pidlist and ppidlist as comma-separated string
	allpids=(${pids[@]} ${ppids[@]})
	a2s "${allpids[@]}"
	allpidl=${a2sresult}
	processes=$(ps --forest --format 'pid,ppid,user:10,tty,stat,pcpu,nlwp,time,pmem,rss:10,drs:10,size:10,lstart,cmd' --pid=${allpidl} --ppid=${allpidl})
	message="${msg} pids=${allpidl}"$'\n'""$'\n'"${processes}"
	logger -p local3.warning "${message}"
	mail -s "${MYSELF}@${MYNODE} ${msg}" "${NOTIFY}" <<< "${message}"
}

# Selfie!
SCRIPT=$(readlink -nf "${0}")
HOMEDIR=$(dirname "${SCRIPT}")
MYSELF=$(basename "${SCRIPT}" ".${SCRIPT##*.}")
MYNODE=$(hostname -f)

# Constants
PSREX='([0-9]+)\s+([0-9]+)\s+(\w+\s+\w+\s+[0-9]+\s+[0-9]+:[0-9]+:[0-9]+\s+[0-9]+)\s+(.+)'
CRONTIMEOUT=240
NOTIFY='mymail@example.com'

# Get scheduler processes
res=0

npid=0
pids=()
ppids=()
lstarts=()
cmds=()
pslist=$(ps --no-headers --format 'pid,ppid,lstart,cmd' -C 'cron')
while read process; do
	if [[ ${process} =~ ${PSREX} ]]; then
		pid="${BASH_REMATCH[1]}"
		ppid="${BASH_REMATCH[2]}"
		lstart="${BASH_REMATCH[3]}"
		cmd="${BASH_REMATCH[4]}"

		# Exclude process with parent = root
		if [[ ${ppid} > 1 ]]; then
			# Get process duration (minutes)
			running=$(($(($(date +%s) - $(date -d "${lstart}" +%s))) / 60))
			if [[ $running > $CRONTIMEOUT ]]; then
				pids[$npid]="${pid}"
				ppids[$npid]="${ppid}"
				lstarts[$npid]="${lstart}"
				cmds[$npid]="${cmd}"
				npid=$((npid+1))
				res=1
			fi
		fi
	fi

done <<< "${pslist}"

# Report processes runnig longer than $CRONTIMEOUT
if [[ ${npid} > 0 ]]; then
	# Log to rsyslog and send warning mail
	msg='Stuck crontab'
	notify
fi

exit $res

