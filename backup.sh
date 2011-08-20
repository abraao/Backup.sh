#!/bin/bash

#------------------------------------------------------------------------------
#- Cronjobs
#------------------------------------------------------------------------------
#You should create twelve cronjobs for this backup script. Three for code
#backup (daily, weekly, monthly), three for database backup
#(daily, weekly, monthly), three for code cleanup (daily, weekly, monthly),
#and three for database cleanup (daily, weekly, monthly).
#
#Below are sample cronjob entries for these twelve cronjobs:
##
## Database backup
##
## Backup the database daily at 12:00AM
#0 0 * * * /home/backup/backup_scripts/backup.sh --backup database daily
## Backup the database weekly every Sunday at 12:30AM
#30 0 * * 0 /home/backup/backup_scripts/backup.sh --backup database weekly
## Backup the database on the first of every month at 1:00AM
#0 1 1 * * /home/backup/backup_scripts/backup.sh --backup database monthly
#
##
## Code backup
##
## Backup the code daily at 1:30AM
#30 1 * * * /home/backup/backup_scripts/backup.sh --backup code daily
## Backup the code weekly every Sunday at 2:00AM
#0 2 * * 0 /home/backup/backup_scripts/backup.sh --backup code weekly
## Backup the code on the first of every month at 2:30AM
#30 2 1 * * /home/backup/backup_scripts/backup.sh --backup code monthly
#
##
## Database cleanup
##
## Cleanup the database daily at 3:00AM
#0 3 * * * /home/backup/backup_scripts/backup.sh --cleanup database daily
## Cleanup the database weekly every Sunday at 3:30AM
#30 3 * * 0 /home/backup/backup_scripts/backup.sh --cleanup database weekly
## Cleanup the database on the first of every month at 4:00AM
#0 4 1 * * /home/backup/backup_scripts/backup.sh --cleanup database monthly
#
##
## Code cleanup
##
## Cleanup the code daily at 4:30AM
#30 4 * * * /home/backup/backup_scripts/backup.sh --cleanup code daily
## Cleanup the code weekly every Sunday at 5:00AM
#0 5 * * 0 /home/backup/backup_scripts/backup.sh --cleanup code weekly
## Cleanup the code on the first of every month at 5:30AM
#30 5 1 * * /home/backup/backup_scripts/backup.sh --cleanup code monthly

##############################################################################
# Configuration
##############################################################################
#
# Database backup config
#
# Filename prefix/task id
DATABASE_TASK_ID="database"
# Where to place backup files
DATABASE_BACKUP_DIR="/mnt/backup/${DATABASE_TASK_ID}"
# Maximum number of daily, weekly, monthly files to keep
MAX_DATABASE_DAILY_BACKUPS=31
MAX_DATABASE_WEEKLY_BACKUPS=8
MAX_DATABASE_MONTHLY_BACKUPS=4
# Set the password in the .my.cnf file in the home directory:
# [client]
# password=your_pass
# See http://dev.mysql.com/doc/refman/5.0/en/password-security.html

#
# CVS backup config
#
# Filename prefix/task id
CVS_TASK_ID="cvs"
# Where to place backup files
CVS_BACKUP_DIR="/mnt/backup/${CVS_TASK_ID}"
# Maximum number of daily, weekly, monthly files to keep
MAX_CVS_DAILY_BACKUPS=31
MAX_CVS_WEEKLY_BACKUPS=8
MAX_CVS_MONTHLY_BACKUPS=4
# Temp dir for cvs
CVS_TEMP_DIR="/tmp/backuptemp/${CVS_TASK_ID}"
# cvs repository
CVSROOT_DIR="/var/lib/cvs"

#
# SVN backup config
#
# Filename prefix/task id
SVN_TASK_ID="svn"
# Where to place backup files
SVN_BACKUP_DIR="/mnt/backup/${SVN_TASK_ID}"
# Maximum number of daily, weekly, monthly files to keep
MAX_SVN_DAILY_BACKUPS=31
MAX_SVN_WEEKLY_BACKUPS=8
MAX_SVN_MONTHLY_BACKUPS=4
# Temp dir for cvs
SVN_TEMP_DIR="/tmp/backuptemp/${SVN_TASK_ID}"

#
# Logging config
#
LOG_FILE="/var/log/backup.log"

#
# Program paths
# maybe this is overkill...
#
MYSQLDUMP_BIN="/usr/bin/mysqldump"
GZIP_BIN="/bin/gzip"
HOSTNAME_BIN="/bin/hostname"
DATE_BIN="/bin/date"
MKDIR_BIN="/bin/mkdir"
RM_BIN="/bin/rm"
CVS_BIN="/usr/bin/cvs"
FIND_BIN="/usr/bin/find"
TAR_BIN="/bin/tar"
XARGS_BIN="/usr/bin/xargs"
SORT_BIN="/usr/bin/sort"
WC_BIN="/usr/bin/wc"
TOUCH_BIN="/usr/bin/touch"
SVN_BIN="/usr/bin/svn"

#
# Filename prefixes for different frequency types
#
DAILY_FILENAME_PREFIX="daily"
WEEKLY_FILENAME_PREFIX="weekly"
MONTHLY_FILENAME_PREFIX="monthly"

#
# Timestamp formats for different frequency types
# Use with the date command:
# e.g. /bin/date +%Y%m%d_%H%M%Z
#
# Four digit year, followed by two digit month, two digit day,
# 24 hour format hour, minutes, timezone.
# e.g. 20080401_163033EDT
FULL_TIMESTAMP="%Y%m%d_%H%M%S%Z"
# Four digit year, followed by two digit month, two digit day.
# e.g. 20080401
DAILY_TIMESTAMP="%Y%m%d"
# Four digit year, followed by two digit week number.
# e.g. 200817
WEEKLY_TIMESTAMP="%Y%W"
# Four digit year, followed by two digit month.
# e.g. 200804
MONTHLY_TIMESTAMP="%Y%m"

#
# Misc
#
HOSTNAME_TEXT=`${HOSTNAME_BIN}` # Use hostname -f for fully qualified domain name (fqdn)
TIMESTAMP_CMD="${DATE_BIN} +${FULL_TIMESTAMP}"

##############################################################################
# End configuration
##############################################################################

##############################################################################
# Logging
##############################################################################

# Log a message with the given level and text
# @param $1 messageLevel	The message level (ERROR, INFO, WARN)
# @param $2 messageText		The message text.
function Log() {
	local messageLevel=$1
	local messageText=$2
	
	# Default to message level MSG
	if [ ! -n $messageLevel ]; then
		messageLevel="INFO"
	fi
	
	local logMessageText="[`${TIMESTAMP_CMD}`][${messageLevel}]: ${messageText}"
	echo $logMessageText >> "$LOG_FILE"
}

# Log informational messages
# @param $1 messageText		[string]	The message text.
function LogInfo() {
	local messageText=$1

	Log "INFO" "$messageText"
}

# Log a program error and abort the program
# @param $1 messageText		[string]	The message text.
function LogError() {
	local messageText=$1

	Log "ERROR" "$messageText"
	exit 1
}

##############################################################################
# End logging
##############################################################################

# Setup things that need to be done before doing a backup/cleanup
function Setup() {
	if [ ! -f $LOG_FILE ]; then
		${TOUCH_BIN} ${LOG_FILE}
	fi

	if [ ! -d $DATABASE_BACKUP_DIR ]; then
		${MKDIR_BIN} -p ${DATABASE_BACKUP_DIR}
	fi

	if [ ! -d $CODE_BACKUP_DIR ]; then
		${MKDIR_BIN} -p ${CODE_BACKUP_DIR}
	fi
}

# Process program arguments
# @param	$1	backupCommand		Main command, either --backup or --cleanup
# @param	$2	commandTarget		What to operate on (database, code)
# @param	$3	commandFrequency	Frequency indicator [daily, weekly, monthly]
function Main() {
	local backupCommand=$1
	local commandTarget=$2
	local commandFrequency=$3
	
	Setup

	case "$backupCommand" in
		"--backup")
			Backup $commandTarget $commandFrequency
			;;
		"--cleanup")
			Cleanup $commandTarget $commandFrequency
			;;
		"--usage" | *)
			PrintUsage
			;;
	esac
}

# Make the backup of the given target and label according to the given frequency
# @param	$1	backupTarget	What to backup (database, code)
# @param	$2	frequencyType	Backup frequency type [daily, weekly, monthly]
function Backup() {
	local backupTarget=$1
	local frequencyType=$2
	
	case "$backupTarget" in
		"${DATABASE_TASK_ID}")
			BackupDatabase $frequencyType
			;;
		"${CVS_TASK_ID}" | "${SVN_TASK_ID}")
			BackupCode $frequencyType $backupTarget
			;;
		*)
			LogError "Unknown backup target ${backupTarget}."
			;;
	esac
}

##############################################################################
# Code backup
##############################################################################

# Make a backup of the code and label according to the given frequency.
# Sample backup filenames:
# * cvs_daily_20080823_ts_20080823_123344EDT.gz
# * svn_weekly_200810_ts_20080823_123344EDT.gz
# * cvs_montly_200809_ts_20080823_123344EDT.gz
# @param	$1	frequencyType	Backup frequency type [daily, weekly, monthly]
# @param	$2	codeType		[svn|cvs] Type of repository to backup.
function BackupCode() {
	local frequencyType=$1
	local codeType=$2
	local backupFilename="${codeType}_"
	local frequencyTimestamp=""
	
	case "$frequencyType" in
		"daily")
			backupFilename+="${DAILY_FILENAME_PREFIX}_"
			frequencyTimestamp="${DAILY_TIMESTAMP}"
			;;
		"weekly")
			backupFilename+="${WEEKLY_FILENAME_PREFIX}_"
			frequencyTimestamp="${WEEKLY_TIMESTAMP}"
			;;
		"monthly")
			backupFilename+="${MONTHLY_FILENAME_PREFIX}_"
			frequencyTimestamp="${MONTHLY_TIMESTAMP}"
			;;
		*)
			LogError "Unknown code backup frequency type $frequencyType"
			;;
	esac
	
	local fullTimestampText=`${DATE_BIN} +${FULL_TIMESTAMP}`
	local frequencyTimestampText=`${DATE_BIN} +${frequencyTimestamp}`
	
	backupFilename+="${frequencyTimestampText}_ts_${fullTimestampText}"
	
	local backupFilepath=""
	
	case "$codeType" in
		"${CVS_TASK_ID}")
			$backupFilepath="${CVS_BACKUP_DIR}"
			;;
		"${SVN_TASK_ID}")
			$backupFilepath="${SVN_BACKUP_DIR}"
			;;
	esac
	
	backupFilepath+="/${backupFilename}"
	
	CreateCodeBackupFile $backupFilepath $codeType
}

# Create the code backup file at the specified filepath
# @param	$1	codeFilepath	The full path to the dump file that will
#								contain all source code
# @param	$2	codeType		[svn|cvs] Type of repository to backup.
function CreateCodeBackupFile() {
	local codeFilepath=$1
	local codeType=$2
	
	local codeWorkArea=""
	
	case "$codeType" in
		"${SVN_TASK_ID}")
			$codeWorkArea="$SVN_TEMP_DIR"
			;;
		"${CVS_TASK_ID}")
			$codeWorkArea="$CVS_TEMP_DIR"
			;;
	esac

	# Clean up staging area if it exists.
	if [ -d $codeWorkArea ]; then
		`${RM_BIN} -rf ${codeWorkArea}`
	fi
	
	# Create staging area
	`${MKDIR_BIN} -p ${codeWorkArea}`
	
	CheckoutCode $codeWorkArea $codeType
	
	# Tar staging area
	local tarballFilepath="${codeFilepath}.tar"
	`cd ${codeWorkArea} && ${TAR_BIN} -cf $tarballFilepath *`
	
	CompressFile $tarballFilepath
	
	local compressedTarballFilepath="${tarballFilepath}.gz"
	ErrorCheckFile $compressedTarballFilepath
	
	# Remove staging area
	`${RM_BIN} -rf ${codeWorkArea}`
}

# Check out source code from the repository
# @param	$1	codeWorkArea	The dir to which to checkout the code.
# @param	$2	codeType		[svn|cvs] Type of repository to backup.
function CheckoutCode() {
	local codeWorkArea=$1
	local codeType=$2
	
	case "$codeType" in
		"${SVN_TASK_ID}")
			;;
		"${CVS_TASK_ID}")
			CheckoutCVS $codeWorkArea
			;;
	esac
}

# Checkout the projects in the CVS repository and remove CVS metadata
# @param	$1	codeWorkArea	The dir to which to checkout the code.
function CheckoutCVS() {
	local codeWorkArea=$1
	
	# Check out all projects/modules to staging area
	# -Q = make command really quiet
	`cd ${codeWorkArea} && ${CVS_BIN} -Q -d ${CVSROOT} checkout .`

	if [ $? -ne 0 ]; then
		LogError "Error while checking out the source code."
	fi
	
	# Remove CVS metadata from projects
	`${FIND_BIN} ${codeWorkArea} -iname "CVS" -type d -print0 | ${XARGS_BIN} -0 ${RM_BIN} -rf`
	`${FIND_BIN} ${codeWorkArea} -iname "CVSROOT" -type d -print0 | ${XARGS_BIN} -0 ${RM_BIN} -rf`
}

# Checkout the projects in the SVN repository and remove SVN metadata
# @param	$1	codeWorkArea	The dir to which to checkout the code.
function CheckoutSVN() {
	local codeWorkArea=$1
	
	# Check out all projects/modules to staging area
	# -Q = make command really quiet
	`cd ${codeWorkArea} && ${CVS_BIN} -Q -d ${CVSROOT} checkout .`

	if [ $? -ne 0 ]; then
		LogError "Error while checking out the source code."
	fi
	
	# Remove SVN metadata from projects
	#`${FIND_BIN} ${codeWorkArea} -iname ".svn" -type d -print0 | ${XARGS_BIN} -0 ${RM_BIN} -rf`
	#`${FIND_BIN} ${codeWorkArea} -iname "CVSROOT" -type d -print0 | ${XARGS_BIN} -0 ${RM_BIN} -rf`
}

##############################################################################
# End code backup
##############################################################################

##############################################################################
# Database backup
##############################################################################

# Make a backup of the database and label according to the given frequency.
# Sample backup filenames:
# * database_daily_20080823_ts_20080823_123344EDT.gz
# * database_weekly_200810_ts_20080823_123344EDT.gz
# * database_montly_200809_ts_20080823_123344EDT.gz
# @param	$1	frequencyType	Backup frequency type [daily, weekly, monthly]
function BackupDatabase() {
	local frequencyType=$1
	local backupFilename="${DATABASE_TASK_ID}_"
	local frequencyTimestamp=""
	
	case "$frequencyType" in
		"daily")
			backupFilename+="${DAILY_FILENAME_PREFIX}_"
			frequencyTimestamp="${DAILY_TIMESTAMP}"
			;;
		"weekly")
			backupFilename+="${WEEKLY_FILENAME_PREFIX}_"
			frequencyTimestamp="${WEEKLY_TIMESTAMP}"
			;;
		"monthly")
			backupFilename+="${MONTHLY_FILENAME_PREFIX}_"
			frequencyTimestamp="${MONTHLY_TIMESTAMP}"
			;;
		*)
			LogError "Unknown database backup frequency type $frequencyType"
			;;
	esac
	
	local fullTimestampText=`${DATE_BIN} +${FULL_TIMESTAMP}`
	local frequencyTimestampText=`${DATE_BIN} +${frequencyTimestamp}`
	
	backupFilename+="${frequencyTimestampText}_ts_${fullTimestampText}"
	
	local backupFilepath="${DATABASE_BACKUP_DIR}/${backupFilename}"
	
	CreateDatabaseBackupFile $backupFilepath
}

# Create the database backup file at the specified filepath
# @param	$1	dumpFilepath	The full path to the dump file that will
#								contain all databases
function CreateDatabaseBackupFile() {
	local dumpFilepath=$1
	
	DumpDatabases $dumpFilepath
	ErrorCheckFile $dumpFilepath
	CompressFile $dumpFilepath
}


# Dump all databases from MySQL
# @param	$1	dumpFilepath	The full path to the dump file that will
#								contain all databases
function DumpDatabases() {
	local dumpFilepath=$1

	# http://dev.mysql.com/doc/refman/5.0/en/mysqldump.html#option_mysqldump_quick
	$MYSQLDUMP_BIN	--add-drop-database --add-drop-table \
					--comments \
					--single-transaction \
					--quick \
					--complete-insert --extended-insert \
					--all-databases \
					--result-file="${dumpFilepath}"
	
	if [ $? -ne 0 ]; then
		LogError "Error while dumping all databases."
	fi
}

##############################################################################
# End database backup
##############################################################################

##############################################################################
# Cleanup old backup files
##############################################################################

# Remove old backup files for the given target and frequency type.
# @param	$1	commandTarget		The target for which we're cleaning up
#									old backup files.
# @param	$2	commandFrequency	The labeled frequency of the backup files
#									to cleanup.
function Cleanup() {
	local commandTarget=$1
	local commandFrequency=$2
	
	case "$commandTarget" in
		"${DATABASE_TASK_ID}")
			CleanupDatabaseBackups $commandFrequency
			;;
		"${CVS_TASK_ID} | ${SVN_TASK_ID}")
			CleanupCodeBackups $commandFrequency
			;;
		*)
			LogError "Unknown cleanup target ${commandTarget}."
			;;
	esac
}

# Clean up old database backup files.
# @param	$1	commandFrequency	The labeled frequency of the backup files
#									to cleanup.
function CleanupDatabaseBackups() {
	local commandFrequency=$1
	local backupDir=$DATABASE_BACKUP_DIR
	local maxBackupFiles=$MAX_DATABASE_DAILY_BACKUPS
	
	case "$commandFrequency" in
		"daily")
			maxBackupFiles=$MAX_DATABASE_DAILY_BACKUPS
			;;
		"weekly")
			maxBackupFiles=$MAX_DATABASE_WEEKLY_BACKUPS
			;;
		"monthly")
			maxBackupFiles=$MAX_DATABASE_MONTHLY_BACKUPS
			;;
		*)
			LogError "Unknown cleanup frequency type for database ${commandFrequency}."
			;;
	esac
	
	CleanupBackupDir $backupDir $maxBackupFiles $commandFrequency
}

# Clean up old code backup files.
# @param	$1	commandFrequency	The labeled frequency of the backup files
#									to cleanup.
function CleanupCodeBackups() {
	local commandFrequency=$1
	local backupDir=$CODE_BACKUP_DIR
	local maxBackupFiles=$MAX_CODE_DAILY_BACKUPS
	
	case "$commandFrequency" in
		"daily")
			maxBackupFiles=$MAX_CODE_DAILY_BACKUPS
			;;
		"weekly")
			maxBackupFiles=$MAX_CODE_WEEKLY_BACKUPS
			;;
		"monthly")
			maxBackupFiles=$MAX_CODE_MONTHLY_BACKUPS
			;;
		*)
			LogError "Unknown cleanup frequency type for code ${commandFrequency}."
			;;
	esac
	
	CleanupBackupDir $backupDir $maxBackupFiles $commandFrequency
}

# Remove old backup files so the total number of backup files is under
# the given limit
# @param	$1	$backupDir			The directory containing the backup files
# @param	$2	$maxBackupFiles		The maximum number of files in the backup
#									directory
# @param	$3	$frequencyPrefix	A string representing the frequency prefix
#									[daily|weekly|monthly]
function CleanupBackupDir() {
	local backupDir=$1
	local maxBackupFiles=$2
	local frequencyPrefix=$3

	if [ ! -e $backupDir ]; then
		LogError "Backup directory ${backupDir} does not exist!"
	fi
	
	if [ ! -w $backupDir ]; then
		LogError "Backup directory ${backupDir} is not writable!"
	fi

	local backupFiles=`${FIND_BIN} ${backupDir} -iname "*${frequencyPrefix}*" | ${SORT_BIN}`
	
	local numBackupFiles=`${FIND_BIN} ${backupDir} -iname "*${frequencyPrefix}*" | ${WC_BIN} -l`
	local numBackupFilesToDelete=$[$numBackupFiles - $maxBackupFiles]

	if [ $numBackupFilesToDelete -gt 0 ] ; then
		local numBackupFilesDeleted=0
		for backupFile in $backupFiles ; do
			`${RM_BIN} -f "$backupFile"`
			
			if [ -f $backupFile ] ; then
				LogError "Could not remove backup file ${backupFile}"
			else
				LogInfo "Removed backup file ${backupFile}"
			fi
			
			# Use "let" to add numbers
			let numBackupFilesDeleted=1+$numBackupFilesDeleted
			
			if [ $numBackupFilesDeleted -ge $numBackupFilesToDelete ] ; then
				break
			fi
		done
	else
		LogInfo "No backup files to delete. There are ${numBackupFiles} dump files in ${backupDir}. Maximum is ${maxBackupFiles} files."
	fi
}

##############################################################################
# End cleanup old backup files
##############################################################################

##############################################################################
# Common functions
##############################################################################

# Check the file for obvious errors:
# * Does the file exist?
# * Does the file have size zero?
# @param	$1	filepath	The full path to the file.
function ErrorCheckFile() {
	local filepath=$1

	# Does file exist?
	if [ ! -f $filepath ]; then
		LogError "Cannot file dump file ${filepath}!"
	fi
	
	# Is file empty?
	if [ ! -s $filepath ]; then
		LogError "Dump file ${filepath} has size zero!"
	fi
}

# Compress the specified file with the highest (vs fastest) compression.
# @param	$1	filepath	The full path to the file
function CompressFile() {
	local filepath=$1

	# --best = highest compression, slowest
	# --fast = fastest compression, lowest
	`$GZIP_BIN --best $filepath`
}

##############################################################################
# End common functions
##############################################################################

# Print program usage
function PrintUsage() {
cat <<-EOS
	Usage: $0 [--backup|--cleanup] [database|code] [daily|weekly|monthly]
		--backup				Backup the target.
		--cleanup				Cleanup old backup files for the target.
		[database|code]			What to backup or cleanup backup files for.
		[daily|weekly|montly]	Frequency type for labeling/cleaninup backup
								files.
EOS
}

# Call the main function and pass it all the arguments fed to the script
Main $*

# Exit sucessfully
exit 0