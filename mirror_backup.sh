#!/bin/bash
#
# Creates mirror backups of SOURCE (arg 1) in TARGET (arg 2) using rsync
#
#	Oct. 16th, 2009	created (Pascal Pfiffner)
#

# Setup
SOURCE=$1
TARGET=$2

MODE='-rlt  --numeric-ids'			# use -a for a complete backup. Use -rlt to skip permissions
LOGDATEFORMAT='+%F %H:%M:%S'		# prepended to each echo command
NOTICE_LATEST_BACKUP="/tmp/latest_archive_backup"		# if set will print OK or FAIL and the date to the given file
CHMOD='a-w'							# chmod to apply to all backupped files
EXCLUDE='/etc/rsync_exclude'		# path to a file that contains file names to exclude


# check arguments
if [ 'xx' = "$SOURCE"'xx' ]; then
	echo $(date "$LOGDATEFORMAT")' [FAIL]  No source provided, aborting'
	exit 1
fi
if [ 'xx' = "$TARGET"'xx' ]; then
	echo $(date "$LOGDATEFORMAT").' [FAIL]  No target provided, aborting'
	exit 1
fi


# create target dir if needed
if [ ! -d "$TARGET" ]; then
	mkdir "$TARGET"
	if [[ 0 != $? ]]; then
		echo $(date "$LOGDATEFORMAT")" [FAIL]  Failed to create target directory $TARGET. Aborting"
		exit 1
	fi
fi


# chmod and exclude arguments
CHMODARG=''
if [ 'xx' != 'xx'$CHMOD ]; then
	CHMODARG="--chmod=$CHMOD"
fi
EXCLUDEARG=''
if [ 'xx' != 'xx'$EXCLUDE ]; then
	EXCLUDEARG="--exclude-from=$EXCLUDE"
fi



# assume SSH usage when SOURCE or TARGET contains an @
# we want to use this script from launchd, whose environment is not aware of ssh-agent. Tell him about it!
# you only need to set SSH_ASKPASS if you have a passphrase for your ssh key set (which you should!)
# I have a script that simply echo-es my password, named 'catp', in root's home directory, chmodded to 0700
# THIS IS A SECURITY RISK, but I've found no other solution to this so far
if [ 'xx'"$SOURCE" = 'xx'$(echo "$SOURCE" | grep @) ] || [ 'xx'"$TARGET" = 'xx'$(echo "$TARGET" | grep @) ]; then
	echo $(date "$LOGDATEFORMAT")" -->  Will access source or target over SSH, trying ssh-add"
	export DISPLAY=none:0.0
	export SSH_ASKPASS='/var/root/catp'
	if [ ! -f $SSH_ASKPASS ]; then
		echo $(date "$LOGDATEFORMAT")" [FAIL]  Failed to locate SSH_ASKPASS. Aborting"
		exit 1
	fi
	eval $(/usr/bin/ssh-agent -s) 1>/dev/null
	/usr/bin/ssh-add </dev/null 1>/dev/null
fi


# let's do it!
echo $(date "$LOGDATEFORMAT")" -->  Going to create backup in $TARGET"
echo $(date "$LOGDATEFORMAT")" --->  rsync $MODE $CHMODARG $EXCLUDEARG --delete $SOURCE/ $TARGET/"
rsync $MODE $CHMODARG $EXCLUDEARG --delete "$SOURCE/" "$TARGET/"


if [[ 0 != $? ]]; then
	echo $(date "$LOGDATEFORMAT")" [FAIL]  Creating backup failed"
	exit 1
fi


# done
echo $(date "$LOGDATEFORMAT")" -->  Done"
if [ 'xx' != $NOTICE_LATEST_BACKUP'xx' ]; then
	echo "OK	"$(date "+%F %H:%M:%S") >$NOTICE_LATEST_BACKUP
fi


exit 0
