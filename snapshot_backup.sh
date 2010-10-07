#!/bin/bash
#
# Creates snapshot backups of SOURCE (arg 1) in TARGET (arg 2) using rsync
#
#	Oct. 5th, 2009	created (Pascal Pfiffner)
#

# Setup
SOURCE=$1
TARGET=$2

MODE='-rlt --numeric-ids'			# use -a for a complete backup. Use -rlt to skip permissions
PURGE_IF_OLDER=180					# delete snapshots after this many days, min 1 day
USE_TIMESTAMP=0						# if true creates snapshot directories including timestamps (additional to the date)
LOGDATEFORMAT='+%F %H:%M:%S'		# prepended to each echo command
NOTICE_LATEST_BACKUP="/tmp/latest_save_me_backup"		# if set will print OK or FAIL and the date to the given file
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
		exit 1;
	fi
fi


# compose a name to identify the new snapshot
SNAP_NAME=$(date "+%F")
if [[ 1 = $USE_TIMESTAMP ]]; then
	SNAP_NAME=$SNAP_NAME'_'$(date "+%H-%M")
fi
if [ -d "$TARGET/$SNAP_NAME" ]; then
	TS_WARNING=''
	if [[ 0 = $USE_TIMESTAMP ]]; then
		TS_WARNING=' You should set USE_TIMESTAMP to 1 if you backup this frequently.'
	fi
	echo $(date "$LOGDATEFORMAT")" [FAIL]  Snapshot directory $SNAP_NAME already exists.$TS_WARNING Aborting"
	if [ 'xx' != $NOTICE_LATEST_BACKUP'xx' ]; then
		echo "FAIL	$SNAP_NAME" >$NOTICE_LATEST_BACKUP
	fi
	exit 1;
fi


# use the latest snapshot directory as linking reference
REFERENCE=$(ls -U "$TARGET" | tail -n1)		# why the hell does this sort the oldest files first??
if [ ! -d "$TARGET/$REFERENCE" ]; then
	REFERENCE=''
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


# no reference, so most likely first backup!
if [ 'xx' = $REFERENCE'xx' ]; then
	echo $(date "$LOGDATEFORMAT")" -->  Going to create first backup in $SNAP_NAME"
	echo $(date "$LOGDATEFORMAT")" --->  rsync $MODE $CHMODARG $EXCLUDEARG $SOURCE/ $TARGET/$SNAP_NAME/"
	rsync $MODE $CHMODARG $EXCLUDEARG "$SOURCE/" "$TARGET/$SNAP_NAME/"

# we have a reference, create a new snapshot
else
	echo $(date "$LOGDATEFORMAT")" -->  Going to create snapshot in $SNAP_NAME, hardlinking to $REFERENCE"
	echo $(date "$LOGDATEFORMAT")" --->  rsync $MODE $CHMODARG $EXCLUDEARG --delete --link-dest=$TARGET/$REFERENCE $SOURCE/ $TARGET/$SNAP_NAME/"
	rsync $MODE $CHMODARG $EXCLUDEARG --delete --link-dest="$TARGET/$REFERENCE" "$SOURCE/" "$TARGET/$SNAP_NAME/"
fi

if [[ 0 != $? ]]; then
	echo $(date "$LOGDATEFORMAT")" [FAIL]  Creating snapshot failed"
	if [ 'xx' != $NOTICE_LATEST_BACKUP'xx' ]; then
		echo "FAIL	$SNAP_NAME" >$NOTICE_LATEST_BACKUP
	fi
	exit 1
fi


# delete snapshots older than PURGE_IF_OLDER days
if [[ $PURGE_IF_OLDER > 0 ]]; then
	for oldsnapshot in $(find "$TARGET" -ctime +"$PURGE_IF_OLDER"d -depth 1); do		# got errors using -exec rm -r {} \;
		rm -r "$oldsnapshot"
	done
fi


# done
if [[ 0 != $? ]]; then
	echo $(date "$LOGDATEFORMAT")" [FAIL]  Deleting older snapshots failed"
	if [ 'xx' != $NOTICE_LATEST_BACKUP'xx' ]; then
		echo "FAIL	$SNAP_NAME" >$NOTICE_LATEST_BACKUP
	fi
	exit 1
else
	echo $(date "$LOGDATEFORMAT")" -->  Done"
	if [ 'xx' != $NOTICE_LATEST_BACKUP'xx' ]; then
		echo "OK	$SNAP_NAME" >$NOTICE_LATEST_BACKUP
	fi
fi


exit 0
