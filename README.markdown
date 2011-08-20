## Overview
This is a script I created a long time ago (when CVS was still relevant) to take snapshots of a MySQL database and CVS repo.

I'm making it publicly available in case others find it useful.

## Setup

### Creating the Linux user

	$ su root
	# useradd -m -s /bin/bash backup
	# passwd backup

### Creating a MySQL account for the backup user

1. Create the file .my.cnf in the backup user's home directory:

	$ su backup
	$ touch ~/.my.cnf

2. Add the following text to it:

	$ pico ~/.my.cnf
	[client]
	password=mypassword

3. Set the permissions for the .my.cnf file:

	$ chmod 0400 ~/.my.cnf

4. Create the user in the MySQL server, allow it to connect only from localhost, and give it read-only access to all databases:

	$ mysql -u root -h localhost -p
	mysql> use mysql;
	mysql> GRANT SELECT ON *.* TO 'backup'@'localhost' IDENTIFIED BY 'mypassword';
	mysql> FLUSH PRIVILEGES;

### The backup script

1. Set the configuration variables at the beginning of the file.

2. Put in somewhere, and make it executable only by the backup user. For example:

	$ su backup
	$ chmod 700 ~/Backup/backup.sh

3. The currently designated volume for backup files is /mnt/backup

### Logging

Create a log file for the backup script in /var/log/backup.log if it doesn't already exist, and make it writable only by the backup user:

	$ su root
	# touch /var/log/backup.log
	# chown backup:backup /var/log/backup.log
	# chmod 0644 /var/log/backup.log

Create a cronjob to save and compress the backup file:

	$ su backup
	$ crontab -e

	# Save and compress the backup logfile every month,
	# keep the last ten backup logfiles.
	# Execute on the second of every month, at 11:30PM
	30 11 2 * * /usr/bin/savelog -m 0644 -u backup -g backup -p -n -C -c 10 /var/log/backup.log

### Cronjobs

You should create twelve cronjobs for this backup script. Three for code backup (daily, weekly, monthly), three for database backup
(daily, weekly, monthly), three for code cleanup (daily, weekly, monthly), and three for database cleanup (daily, weekly, monthly).

Below are sample cronjob entries for these twelve cronjobs:

	#
	# Database backup
	#
	# Backup the database daily at 12:00AM
	0 0 * * * /home/backup/Backup/backup.sh --backup database daily
	# Backup the database weekly every Sunday at 12:30AM
	30 0 * * 0 /home/backup/Backup/backup.sh --backup database weekly
	# Backup the database on the first of every month at 1:00AM
	0 1 1 * * /home/backup/Backup/backup.sh --backup database monthly

	#
	# Code backup
	#
	# Backup the code daily at 1:30AM
	30 1 * * * /home/backup/Backup/backup.sh --backup code daily
	# Backup the code weekly every Sunday at 2:00AM
	0 2 * * 0 /home/backup/Backup/backup.sh --backup code weekly
	# Backup the code on the first of every month at 2:30AM
	30 2 1 * * /home/backup/Backup/backup.sh --backup code monthly

	#
	# Database cleanup
	#
	# Cleanup the database daily at 3:00AM
	0 3 * * * /home/backup/Backup/backup.sh --cleanup database daily
	# Cleanup the database weekly every Sunday at 3:30AM
	30 3 * * 0 /home/backup/Backup/backup.sh --cleanup database weekly
	# Cleanup the database on the first of every month at 4:00AM
	0 4 1 * * /home/backup/Backup/backup.sh --cleanup database monthly

	#
	# Code cleanup
	#
	# Cleanup the code daily at 4:30AM
	30 4 * * * /home/backup/Backup/backup.sh --cleanup code daily
	# Cleanup the code weekly every Sunday at 5:00AM
	0 5 * * 0 /home/backup/Backup/backup.sh --cleanup code weekly
	# Cleanup the code on the first of every month at 5:30AM
	30 5 1 * * /home/backup/Backup/backup.sh --cleanup code monthly

To create the cron file, login as the backup user, open up the crontab, and paste the cronjob entries.

	$ su backup
	$ crontab -e

### TODO

* Check the size of backup files more accurately. A 91 byte code backup file is very likely corrupted.
* Verify all errors are being logged.

## Contact
Abraao (Abe) Lourenco backupsh@guaranacode.com
