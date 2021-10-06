#!/bin/bash

unset http_proxy
unset https_proxy

PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

# Dates
DATE=$(date +%Y%m%d_%H:%M:%S)
DATE_0DA=$(date -d "0 days ago" +"%Y%m%d")
DATE_1DA=$(date -d "1 days ago" +"%Y%m%d")

# Descriptions
NAME="MongoDB"
FILE_NAME="$NAME"_"$DATE_1DA"

# Local Paths
DATA_DIR="/data"     # This path is used for checking disk usage on it when backup process is finished !!
BACKUP_DIR="/data/backup/"
UNCOMPRESSED_BK_DIR="$BACKUP_DIR""uncompressed_archive/"
COMPRESSED_BK_DIR="$BACKUP_DIR""compressed_archive/"
W_BK_DIR="$UNCOMPRESSED_BK_DIR""weekly/"
M_BK_DIR="$UNCOMPRESSED_BK_DIR""monthly/"
BK_FILE_NAME="$NAME"_"$DATE_0DA"
BK_FILE_PATH="$UNCOMPRESSED_BK_DIR""$BK_FILE_NAME"
W_BK_FILE_PATH="$W_BK_DIR""$BK_FILE_NAME"
M_BK_FILE_PATH="$M_BK_DIR""$BK_FILE_NAME"

# Logs Paths
LOGS_DIR="$BACKUP_DIR""logs/"
EVENT_LOG="$LOGS_DIR""events.log"
WEEKLY_LOG="$LOGS_DIR""weekly.log"
MONTHLY_LOG="$LOGS_DIR""monthly.log"

# NFS Paths
NFS_DIR="/mnt/storage/mongo_backup/"
DAILY_PATH="$NFS_DIR""daily/"
WEEKLY_PATH="$NFS_DIR""weekly/"
MONTHLY_PATH="$NFS_DIR""monthly/"

# BIN
EXEC_AWK=$(which awk)
EXEC_CURL=$(which curl)
EXEC_DF=$(which df)
EXEC_DU=$(which du)
EXEC_ECHO=$(which echo)
EXEC_FIND=$(which find)
EXEC_GREP=$(which grep)
EXEC_HEAD=$(which head)
EXEC_HOSTNAMECTL=$(which hostnamectl)
EXEC_IFCONFIG=$(which ifconfig)
EXEC_LS=$(which ls)
EXEC_MKDIR=$(which mkdir)
EXEC_MONGO=$(which mongo)
EXEC_MONGODUMP=$(which mongodump)
EXEC_MV=$(which mv)
EXEC_PIGZ=$(which pigz)
EXEC_RM=$(which rm)
EXEC_TAR=$(which tar)
EXEC_XARGS=$(which xargs)

# Host Info
HOST_NAME=$($EXEC_HOSTNAMECTL | $EXEC_GREP -i hostname | $EXEC_AWK '{print $3}')
HOST_IP=$($EXEC_IFCONFIG | $EXEC_GREP inet | $EXEC_GREP -v inet6 | $EXEC_GREP 192.168.71 | $EXEC_AWK '{print $2}')
ISEVERITY="info"
WSEVERITY="warning"
TITLE="Daily-Backup"
SDESC="Backup Completed Successfully !!"
WDESC="Backup failed !!"

$EXEC_MKDIR -p "$UNCOMPRESSED_BK_DIR"
$EXEC_MKDIR -p "$COMPRESSED_BK_DIR"
$EXEC_MKDIR -p "$LOGS_DIR"
$EXEC_MKDIR -p "$W_BK_DIR"
$EXEC_MKDIR -p "$M_BK_DIR"
$EXEC_MKDIR -p "$DAILY_PATH"
$EXEC_MKDIR -p "$WEEKLY_PATH"
$EXEC_MKDIR -p "$MONTHLY_PATH"

# Credentials
FLE="$BACKUP_DIR"".passwd"
if [[ ! -f $FLE || -z $FLE ]];then
    touch $FLE
    cat <<- EOF >> $EVENT_LOG
    "Your credential file either does not exist or is empty.
    please put your username & password in $FLE encoded in base64"
    ----------------------------------------------------------------------------
EOF
exit
fi

USR=$($EXEC_AWK '{print $1}' $FLE | base64 -d)
PASSWD=$($EXEC_AWK '{print $2}' $FLE | base64 -d)
MONGO_HOST="127.0.0.1"
MONGO_PORT="27017"
AUTH_DB="admin"

# Functions
function dailyBackup {
    ############---COMPRESS & Remove---############
    $EXEC_ECHO "Start Cleaning daily path , Compressing previous backup and removing the uncompressed one ... " >> $EVENT_LOG
    $EXEC_ECHO "Started at $(date +%Y-%m-%d---%T) " >> $EVENT_LOG
    $EXEC_FIND $DAILY_PATH -type f -mtime +5 | $EXEC_XARGS -I {} $EXEC_RM -rf {}
    $EXEC_FIND $COMPRESSED_BK_DIR -name '*.tar.gz' -type f | $EXEC_XARGS -I {} $EXEC_RM -rf {}
	if [[ -d $UNCOMPRESSED_BK_DIR$FILE_NAME ]];then
        $EXEC_ECHO "Uncompressed Backup File Name: $FILE_NAME " >> $EVENT_LOG
    	$EXEC_FIND $UNCOMPRESSED_BK_DIR -maxdepth 1 -type d -mtime +1 | $EXEC_GREP $NAME | $EXEC_XARGS -I {} $EXEC_RM -rf {}
        cd $UNCOMPRESSED_BK_DIR
        $EXEC_TAR cfP - $FILE_NAME | $EXEC_PIGZ -9 -p 25 > $COMPRESSED_BK_DIR$FILE_NAME.tar.gz
        $EXEC_RM -rf $UNCOMPRESSED_BK_DIR$FILE_NAME
    else
		FILE_NAME=$($EXEC_LS -t1 $UNCOMPRESSED_BK_DIR | $EXEC_GREP $NAME | $EXEC_HEAD -n1)
        $EXEC_ECHO "Uncompressed Backup File Name: $FILE_NAME " >> $EVENT_LOG
        cd $UNCOMPRESSED_BK_DIR
		$EXEC_TAR cfP - $FILE_NAME | $EXEC_PIGZ -9 -p 25 > $COMPRESSED_BK_DIR$FILE_NAME.tar.gz
		$EXEC_RM -rf $UNCOMPRESSED_BK_DIR$FILE_NAME
    	$EXEC_FIND $UNCOMPRESSED_BK_DIR -maxdepth 1 -type d -mtime +1 | $EXEC_GREP $NAME | $EXEC_XARGS -I {} $EXEC_RM -rf {}
	fi
    $EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T) " >> $EVENT_LOG

	############---BACKUP---############
    $EXEC_ECHO "Taking new backup at $UNCOMPRESSED_BK_DIR... " >> $EVENT_LOG
    $EXEC_ECHO "Backup Name: $BK_FILE_NAME" >> $EVENT_LOG
    $EXEC_ECHO "Started at $(date +%Y-%m-%d---%T)" >> $EVENT_LOG

	### Taking Backup ###
    cd $UNCOMPRESSED_BK_DIR
    ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --out ${BK_FILE_NAME}
    bstatus=$?
    BK_SIZE=$($EXEC_DU -sh $BK_FILE_PATH | $EXEC_AWK '{print$1}')
    $EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T) " >> $EVENT_LOG

	# Moving Last Compressed Backup to NFS
    $EXEC_ECHO "Moving last compressed backup to $DAILY_PATH ..." >> $EVENT_LOG
    $EXEC_ECHO "Started at $(date +%Y-%m-%d---%T) " >> $EVENT_LOG
    $EXEC_MV $COMPRESSED_BK_DIR$FILE_NAME.tar.gz $DAILY_PATH
    $EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T) " >> $EVENT_LOG
	$EXEC_ECHO "Backup process completed successfully...! " >> $EVENT_LOG
    }
function weeklyBackup {
	############---Clean NFS---############
	$EXEC_ECHO "Start Cleaning weekly path and removing uncompressed backup if any exists ... " >> $WEEKLY_LOG
	$EXEC_ECHO "Started at $(date +%Y-%m-%d---%T) " >> $WEEKLY_LOG
	$EXEC_FIND $WEEKLY_PATH -type f -mtime +7 | $EXEC_XARGS -I {} $EXEC_RM -rf {}
	$EXEC_FIND $W_BK_DIR -maxdepth 1 -type d | $EXEC_XARGS -I {} $EXEC_RM -rf {}
    $EXEC_FIND $COMPRESSED_BK_DIR -name '*.tar.gz' -type f | $EXEC_XARGS -I {} $EXEC_RM -rf {}
    $EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T) " >> $WEEKLY_LOG

	############---BACKUP,Compress,Move to NFS---############
    $EXEC_ECHO "Taking new backup at $W_BK_DIR... " >> $WEEKLY_LOG
    $EXEC_ECHO "Backup Name: $BK_FILE_NAME" >> $WEEKLY_LOG
	$EXEC_ECHO "Started at $(date +%Y-%m-%d---%T) " >> $WEEKLY_LOG

	### Taking Backup ###
    $EXEC_MKDIR -p "$W_BK_DIR"
    cd $W_BK_DIR
    ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --out ${BK_FILE_NAME}
    bstatus=$?
    BK_SIZE=$($EXEC_DU -sh ${W_BK_FILE_PATH} | $EXEC_AWK '{print$1}')
    $EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T) " >> $WEEKLY_LOG

	# Compress & move backup to NFS
    $EXEC_ECHO "Moving last compressed backup to $WEEKLY_PATH ..." >> $WEEKLY_LOG
	$EXEC_ECHO "Started at $(date +%Y-%m-%d---%T) " >> $WEEKLY_LOG
    cd $W_BK_DIR
	$EXEC_TAR cfP - $BK_FILE_NAME | $EXEC_PIGZ -9 -p 25 > $COMPRESSED_BK_DIR$BK_FILE_NAME.tar.gz
	$EXEC_MV $COMPRESSED_BK_DIR$BK_FILE_NAME.tar.gz $WEEKLY_PATH
	$EXEC_RM -rf $W_BK_FILE_PATH
    $EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T) " >> $WEEKLY_LOG
	$EXEC_ECHO "Backup process completed successfully...! " >> $WEEKLY_LOG
	$EXEC_ECHO "-----------------------" >> $WEEKLY_LOG
    }
function monthlyBackup {
	############---Clean NFS---############
	$EXEC_ECHO "Start Cleaning monthly path and removing uncompressed backup if any exists ... " >> $MONTHLY_LOG
	$EXEC_ECHO "Started at $(date +%Y-%m-%d---%T) " >> $MONTHLY_LOG
	$EXEC_FIND $MONTHLY_PATH -type f -mtime +31 | $EXEC_XARGS -I {} $EXEC_RM -rf {}
	$EXEC_FIND $M_BK_DIR -type f | $EXEC_XARGS -I {} $EXEC_RM -rf {}
	$EXEC_FIND $COMPRESSED_BK_DIR -name '*.tar.gz' -type f | $EXEC_XARGS -I {} $EXEC_RM -rf {}
	$EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T) " >> $MONTHLY_LOG

	############---BACKUP,Compress,Move to NFS---############
    $EXEC_ECHO "Taking new backup at $M_BK_DIR... " >> $MONTHLY_LOG
    $EXEC_ECHO "Backup Name: $BK_FILE_NAME" >> $MONTHLY_LOG
    $EXEC_ECHO "Started at $(date +%Y-%m-%d---%T)" >> $MONTHLY_LOG

	### Create Backup Path ###
    $EXEC_MKDIR -p "$M_BK_FILE_PATH"
    cd $M_BK_FILE_PATH

	### Taking Backup ###
    ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --archive=${BK_FILE_NAME}.archive
    bstatus=$?
    BK_SIZE=$($EXEC_DU -sh ${M_BK_FILE_PATH} | $EXEC_AWK '{print$1}')
	$EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T) " >> $MONTHLY_LOG

	# Compress & move backup to NFS
    $EXEC_ECHO "Moving last compressed backup to $MONTHLY_PATH ..." >> $MONTHLY_LOG
	$EXEC_ECHO "Started at $(date +%Y-%m-%d---%T) " >> $MONTHLY_LOG
    cd $M_BK_DIR
	$EXEC_TAR cfP - $BK_FILE_NAME | $EXEC_PIGZ -9 -p 25 > $COMPRESSED_BK_DIR$BK_FILE_NAME.tar.gz
	$EXEC_MV $COMPRESSED_BK_DIR$BK_FILE_NAME.tar.gz $MONTHLY_PATH
	$EXEC_RM -rf $M_BK_FILE_PATH
	$EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T) " >> $MONTHLY_LOG
	$EXEC_ECHO "Backup Process completed successfully...! " >> $MONTHLY_LOG
	$EXEC_ECHO "-----------------------" >> $MONTHLY_LOG
    }

# Decision about backup type
if [[ $1 = 'daily' ]] || [[ -z $1 ]];then
    dailyBackup
elif [[ $1 = 'weekly' ]]; then
	weeklyBackup
elif [[ $1 = 'monthly' ]]; then
	monthlyBackup	
fi

#### Sending Notification ####
# ROCKETCHAT
## channel: ap.db.backup.logs
DF_PERCENT=$($EXEC_DF -Ph $DATA_DIR | $EXEC_GREP -Po '\d+(?=%)')
ROCKET_WEBHOOK="http://chat.tasn.ir:3000/hooks/uCpARkovrXfARAbun/SRrT5sjp3MM5yRiP3XitQr6npTy7FWW8RnQyMG4S3GqkpugP"
ROCKET_SMSG='{"alertname":"Database-Backup","emoji":":raccoon:","text":"Message Type: '$ISEVERITY' \n  Message Title: '$TITLE' \n Server IP: '$HOST_IP' \n Server Name: '$HOST_NAME' \n Description:\n '$SDESC' \n Disk Used: '$DF_PERCENT%' \n Backup Size: '$BK_SIZE'"}'
ROCKET_FMSG='{"alertname":"Database-Backup","emoji":":raccoon:","text":"Message Type: '$WSEVERITY' \n  Message Title: '$TITLE' \n Server IP: '$HOST_IP' \n Server Name: '$HOST_NAME' \n Description:\n '$WDESC' \n Disk Used: '$DF_PERCENT%' \n Backup Size: '$BK_SIZE'"}'

$EXEC_ECHO "Sending notification to RocketChat..." >> $EVENT_LOG
$EXEC_ECHO "Started at $(date +%Y-%m-%d---%T)" >> $EVENT_LOG

if [[ $bstatus -eq 0 ]]; then 
    $EXEC_CURL -X POST -H "Content-type:application/json" --data "$ROCKET_SMSG" "$ROCKET_WEBHOOK" >> $EVENT_LOG
else
    $EXEC_CURL -X POST -H "Content-type:application/json" --data "$ROCKET_FMSG" "$ROCKET_WEBHOOK" >> $EVENT_LOG
fi

$EXEC_ECHO "Notification Sent !!" >> $EVENT_LOG
$EXEC_ECHO "Finished at $(date +%Y-%m-%d---%T)" >> $EVENT_LOG
$EXEC_ECHO "------------------------------------" >> $EVENT_LOG