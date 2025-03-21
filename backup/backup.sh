#!/usr/bin/env bash

# This script performs a backup of this system.
# It should be run as root to make sure that all the required files can
# be read and copied.

fail() {
	echo $@
	exit 1
}

if [[ $EUID > 0 ]]; then
	fail "Please run as root."
fi

absolutedir() {
	local abspath
	abspath=$(realpath $1)
	echo $(dirname $abspath)
}

# Convert dates between formats.
# Usage: dateconvert string oldformat newformat
# Echo the date represented by string (in oldformat) in newformat
dateconvert() {
python3 - "$@" <<EOF
from datetime import datetime
from sys import argv
try:
    print(datetime.strptime(argv[1],argv[2]).strftime(argv[3]))
except:
    pass
EOF
}

#########

SHARE=""
SHARECREDS=$(absolutedir $0)/backup-creds.txt

MAXDAYS=7

FILESFROM=$(absolutedir $0)/backup-files.txt

FILEFORMAT=%Y%m%d-%H%M%S-%Z.tar

precmd() {
	:
}

postcmd() {
	:
}

source $(absolutedir $0)/backup-opts.sh

if [[ -z $SHARE ]]; then
	fail "Configuration must set SHARE"
fi

#########

precmd

# Mount the backup share
# If this fails, quit
MOUNT=$(mktemp -d)
MOUNTOPTS=file_mode=0640,dir_mode=0750,uid=0,gid=0,forceuid,forcegid
mount -t smb3 "$SHARE" "$MOUNT" -o "cred=$SHARECREDS,$MOUNTOPTS" || fail "Cannot mount backup location."

# Determine name of backup based on date
FILE=$(date +$FILEFORMAT)
DEST=$MOUNT/$FILE

# Back up files
tar -cf "$DEST" --xattrs --selinux --acls --files-from "$FILESFROM"

# Delete old backups beyond the keep threshold
# TODO
DELBEFORE=$(($(date +%s) - 86400*$MAXDAYS))
for f in $(ls "$MOUNT"); do
	ftime=$(dateconvert $f $FILEFORMAT %s)
	if ! [ -z "$ftime" ] && [ "$ftime" -lt "$DELBEFORE" ]; then
		rm "$MOUNT/$f"
	fi
done

# Unmount the backup share
umount "$MOUNT"
rmdir "$MOUNT"

postcmd
