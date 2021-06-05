#!/bin/bash

unset http_proxy
unset https_proxy

PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
HOSTNAME=$(hostnamectl | grep -i hostname | awk '{print $3}')
HOST_IP=$(ifconfig | grep inet | grep -v inet6 | grep 192.168.71 | awk '{print $2}')
ISEVERITY="info"
WSEVERITY="warning"
TITLE="Daily-Backup"
SDESC="Backup Completed Successfully !!"
WDESC="Backup failed !!"

# ROCKETCHAT
## channel: ap.backup.log
ROCKET_WEBHOOK="http://chat.tasn.ir:3000/hooks/zvL6cyg3kQeAETjkv/RHdfHLXKfk4zcKbSnjSKHjCrbfj6EQfitTAMsjAP5EtXkf5H"
ROCKET_SMSG='{"alertname":"Database-Backup","emoji":":raccoon:","text":"Message Type: '$ISEVERITY' \n  Message Title: '$TITLE' \n Server IP: '$HOST_IP' \n Server Name: '$HOST_NAME' \n Description:\n '$SDESC'"}'
ROCKET_FMSG='{"alertname":"Database-Backup","emoji":":raccoon:","text":"Message Type: '$WSEVERITY' \n  Message Title: '$TITLE' \n Server IP: '$HOST_IP' \n Server Name: '$HOST_NAME' \n Description:\n '$WDESC'"}'

# Dates
DATE=$(date +%Y%m%d_%H:%M:%S)
DATE_0DA=$(date -d "0 days ago" +"%Y%m%d")
DATE_1DA=$(date -d "1 days ago" +"%Y%m%d")

# Descriptions
NAME="MongoDB"
FILE_NAME="$NAME"_"$DATE_1DA"

# Local Paths
BACKUP_PATH="/mnt/backup/"
UNCOMPRESSED_BK_DIR="$BACKUP_PATH""uncompressed_archive/"
COMPRESSED_BK_DIR="$BACKUP_PATH""compressed_archive/"
W_BK_DIR="$UNCOMPRESSED_BK_DIR""weekly/"
M_BK_DIR="$UNCOMPRESSED_BK_DIR""monthly/"

# Logs Paths
LOGS_DIR="$BACKUP_PATH""logs/"
EVENT_LOG="$LOGS_DIR""event.logs"
LOG_NAME="$LOGS_DIR""backup_event.logs"
BK_LOG="backup-progress.logs"
BK_LOG_NAME="$LOGS_DIR""$BK_LOG"

mkdir -p $UNCOMPRESSED_BK_DIR
mkdir -p $COMPRESSED_BK_DIR
mkdir -p $LOGS_DIR
mkdir -p $W_BK_DIR
mkdir -p $M_BK_DIR

# NFS Paths
NFS_DIR="/mnt/nfs-storage/mongo_backup/"
DAILY_PATH="$NFS_DIR""daily/"
WEEKLY_PATH="$NFS_DIR""weekly/"
MONTHLY_PATH="$NFS_DIR""monthly/"

# Services
EXEC_TAR=$(which tar)
EXEC_FIND=$(which find)
EXEC_RM=$(which rm)
EXEC_CURL=$(which curl)
EXEC_MV=$(which mv)
EXEC_MKDIR=$(which mkdir)
EXEC_MONGODUMP=$(which mongodump)

# Credentials
FLE="$S_DIR/.passwd"
USR=$(awk '{print $1}' $FLE | base64 -d)
PASSWD=$(awk '{print $2}' $FLE | base64 -d)
MONGO_HOST="127.0.0.1"
MONGO_PORT="27017"
AUTH_DB="admin"

# Functions
function dailyBackup {
        BK_FILE_NAME="$NAME"_"$DATE_0DA"
        BK_FILE_PATH="$UNCOMPRESSED_BK_DIR""$BK_FILE_NAME"

        echo "Start Taking New Backup at $BK_FILE_PATH... " >> $EVENT_LOG
        echo "Backup Name: $BK_FILE_NAME" >> $EVENT_LOG
        echo "Time Check: $(date +%Y%m%d_%H:%M:%S)" >> $EVENT_LOG

        $EXEC_MKDIR -p "$BK_FILE_PATH"
        cd $BK_FILE_PATH

        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=admin
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_apnsservice 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_hamrafigh 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_mobapp_appconfig 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_mobapp_smsgateway 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_mobapp_sync 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_tourism_engine
        }

function weeklyBackup {
	W_BK_FILE_PATH="$W_BK_DIR""$NAME"_"$DATE_0DA"
	W_BK_FILE_NAME="$NAME"_"$DATE_0DA"

        echo "Start Taking New Backup at $W_BK_FILE_PATH... " >> $EVENT_LOG
        echo "Backup Name: $W_BK_FILE_NAME" >> $EVENT_LOG
        echo "Time Check: $(date +%Y%m%d_%H:%M:%S)" >> $EVENT_LOG

        $EXEC_MKDIR -p "$W_BK_FILE_PATH"
        cd $W_BK_FILE_PATH

        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=admin
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_apnsservice 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_hamrafigh 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_mobapp_appconfig 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_mobapp_smsgateway 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_mobapp_sync 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_tourism_engine

	$EXEC_TAR cfP - $W_BK_FILE_PATH | pigz -9 -p 25 > $COMPRESSED_BK_DIR$W_BK_FILE_NAME.tar.gz
	$EXEC_MV $COMPRESSED_BK_DIR$W_BK_FILE_NAME.tar.gz $WEEKLY_PATH
	$EXEC_FIND $WEEKLY_PATH -mtime +13 -type f -exec rm -rf {} \;
	$EXEC_RM -rf $W_BK_FILE_PATH
	}

function monthlyBackup {
	M_BK_FILE_PATH="$M_BK_DIR""$NAME"_"$DATE_0DA"
	M_BK_FILE_NAME="$NAME"_"$DATE_0DA"

        echo "Start Taking New Backup at $BK_FILE_PATH... " >> $EVENT_LOG
        echo "Backup Name: $M_BK_FILE_NAME" >> $EVENT_LOG
        echo "Time Check: $(date +%Y%m%d_%H:%M:%S)" >> $EVENT_LOG

        $EXEC_MKDIR -p "$M_BK_FILE_PATH"
        cd $M_BK_FILE_PATH

        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=admin
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_apnsservice 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_hamrafigh 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_mobapp_appconfig 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_mobapp_smsgateway 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_mobapp_sync 
        ${EXEC_MONGODUMP} --host=${MONGO_HOST} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} --authenticationDatabase=${AUTH_DB} --db=ap_tourism_engine

	$EXEC_TAR cfP - $M_BK_FILE_PATH | pigz -9 -p 25 > $COMPRESSED_BK_DIR$M_BK_FILE_NAME.tar.gz
	$EXEC_MV $COMPRESSED_BK_DIR$M_BK_FILE_NAME.tar.gz $MONTHLY_PATH
	$EXEC_FIND $MONTHLY_PATH -mtime +60 -type f -exec rm -rf {} \;
	$EXEC_RM -rf $M_BK_FILE_PATH
	}

############---COMPRESS & Remove---############
echo "Start Cleaning daily path , Compressing previous backup and removing the uncompressed one ... " >> $EVENT_LOG
echo "Uncompressed Backup File Name: $FILE_NAME " >> $EVENT_LOG
echo "Time Check: $(date +%Y%m%d_%H:%M:%S) " >> $EVENT_LOG

$EXEC_FIND $DAILY_PATH -mtime +6 -type f -exec rm -rf {} \;
$EXEC_FIND $COMPRESSED_BK_DIR -name '*.tar.gz' -type f -exec rm -rf {} \;
$EXEC_TAR cfP - $UNCOMPRESSED_BK_DIR$FILE_NAME | pigz -9 -p 25 > $COMPRESSED_BK_DIR$FILE_NAME.tar.gz
$EXEC_RM -rf $UNCOMPRESSED_BK_DIR$FILE_NAME

echo "Time Check: $(date +%Y%m%d_%H:%M:%S) " >> $EVENT_LOG
echo "...END " >> $EVENT_LOG

############---BACKUP---############

if [[ $1 = 'daily' ]] || [[ -z $1 ]];then
        dailyBackup
elif [[ $1 = 'weekly' ]]; then
	weeklyBackup
elif [[ $1 = 'monthly' ]]; then
	monthlyBackup	
fi

bstatus=$?

echo "Process completed successfully...! " >> $EVENT_LOG
echo "Time Check: $(date +%Y%m%d_%H:%M:%S) " >> $EVENT_LOG

echo "Sending notification to RocketChat..." >> $EVENT_LOG
echo "Time Check: $(date +%Y%m%d_%H:%M:%S)" >> $EVENT_LOG

if [[ $bstatus -eq 0 ]]; then 
    curl -X POST -H "Content-type:application/json" --data $ROCKET_SMSG $ROCKET_WEBHOOK
else
    curl -X POST -H "Content-type:application/json" --data $ROCKET_FMSG $ROCKET_WEBHOOK 
fi

echo "Notification Sent !!" >> $EVENT_LOG
echo "Time Check: $(date +%Y%m%d_%H:%M:%S)" >> $EVENT_LOG

echo "Moving last compressed backup to $DAILY_PATH ..." >> $EVENT_LOG
echo "Time Check: $(date +%Y%m%d_%H:%M:%S) " >> $EVENT_LOG
$EXEC_MV $COMPRESSED_BK_DIR$FILE_NAME.tar.gz $DAILY_PATH
echo "Time Check: $(date +%Y%m%d_%H:%M:%S) " >> $EVENT_LOG
echo "...END " >> $EVENT_LOG
echo "Finished !" >> $EVENT_LOG
echo "-----------------------" >> $EVENT_LOG