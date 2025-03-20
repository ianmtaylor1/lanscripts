# This file is sourced by backup.sh and contains options to configure
# the backup.
# ALL COMMANDS IN THIS FILE WILL BE RUN AS ROOT, because backup.sh must
# be run as root. Be careful.

# SMB share on which to save the backups.
# (required)
SHARE=//nas.example.com/share/folder

# SMB mount credentials file
# (optional)
# Default: backup-creds.txt in same directory as backup.sh
# See 'man mount.smb3' for the format of this file.
#SHARECREDS=/path/to/backup-creds.txt

# Maximum number of days to keep backups on share
# (optional)
# Default: 7
# Any backups on the share older than MAXDAYS days will be deleted after
# the backup is complete
#MAXDAYS=7

# File name of created archive
# (optional)
# Default: %Y%m%d-%H%M%S-%Z.tar
# Should contain strftime format strings that identify the time to at least
# day resolution, so that automatic deletion works as expected.
#FILEFORMAT=%Y%m%d-%H%M%S-%Z.tar

# File name containing paths to backup
# (optional)
# Default: backup-files.txt in the same directory as backup.sh
# This file is given to the --files-from argument of tar. See the tar
# documentation for more details. By default, tar uses the
# --no-verbatim-files-from option, so this file can contain tar arguments
# in lines starting with a dash. (e.g. --exclude may be useful)
#FILESFROM=/path/to/backup-files.txt

# Function to run before the backup
# (optional)
# Default: no action
# Use this to stop services, create requirements files, etc, before backing
# them up.
#precmd() {
#	echo Preparing to backup...
#}

# Function to run after the backup
# (optional)
# Default: no action
# Use this to restart services, clean up temporary files, etc, after the
# backup is complete
#postcmd() {
#	echo Finalizing backup...
#}

