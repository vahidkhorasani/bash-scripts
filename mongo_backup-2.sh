#!/usr/bin/env bash

#/usr/bin/env bash is more portable than #!/bin/bash.

##############
unset http_proxy
unset https_proxy
set -o nounset #to exit when your script tries to use undeclared variables
set -o errexit #make your script exit when a command fails
set -o pipefail #The exit status of the last command that threw a non-zero exit code is returned.
set -o xtrace

##############
export PATH=/var/lib/mongodb-mms-automation/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

######check backup type#############
if [[ $(date -d "+1 day" +%m) != $(date +%m) ]]; then
    BACKUP_TYPE="mongo_backup_monthly_$(hostname)"
fi

if [[ $(date +%w) -eq 5 ]]; then
	BACKUP_TYPE="mongo_backup_weekly_$(hostname)"
else
    BACKUP_TYPE="mongo_backup_daily_$(hostname)"
fi
####################################

########Rocket Chat#########
RC_SUCCESS_MSG="Mongo backup is finished successfully"
RC_WEBHOOK=""
TITLE="Mongo-Backup"
SDESC="Backup Completed Successfully !!"
ISEVERITY="info"
WSEVERITY="warning"
WDESC="Backup failed !!"
############################

#########DATE VARS##################
CUR_DATE=$(date +%Y%m%d)
CUR_TIME=$(date +%H%M)
Y_DATE=$(date -d "1 days ago" +%Y%m%d)
####################################

########FILES LOCATION##############
BK_DIR="/mongo_backup"
LOGFILE=${BK_DIR}/${BACKUP_TYPE}_${CUR_DATE}_${CUR_TIME}.log
BKP_FILE=${BK_DIR}/${BACKUP_TYPE}_${CUR_DATE}_${CUR_TIME}
BACKUP_RETENTION_DAYS_DAILY=6								#<========================== SET RETENTION FOR TARBALLS
BACKUP_RETENTION_DAYS_WEEKLY=$(((2*7)-1))					#<========================== SET RETENTION FOR TARBALLS
BACKUP_RETENTION_DAYS_MONTHLY=$(((2*30)))					#<========================== SET RETENTION FOR TARBALLS
BACKUP_RETENTION_DAYS_LOGS=$(((3*30)))						#<========================== SET RETENTION FOR LOGS
FLE=${BK_DIR}/.passwd
HOST_IP=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')
####################################
function fail_func(){
FAIL_REASON="${1}"
echo -e "${FAIL_REASON}" | tee -a ${LOGFILE}
local DFDATA=$(df -Ph ${BK_DIR} | grep -Po '\d+(?=%)')
RC_HOOK_FAIL='{"alertname":"Database-Backup","emoji":":raccoon:","text":"Message Type: '${WSEVERITY}' \n  Message Title: '${TITLE}' \n Server IP: '${HOST_IP}' \n Server Name: '$(hostname)' \n Description: '${WDESC}' \n Reason: '"${FAIL_REASON}"' \n Disk Used: '${DFDATA}%'"}'
curl -X POST -H "Content-type:application/json" --data "${RC_HOOK_FAIL}" ${RC_WEBHOOK}
}

#########MESSAGES###################
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

#printf "I ${RED}test${NC} alot\n"
####################################

#------------------------------------BEGIN OF CHECKS------------------------------------------------------------------------------#
echo "" | tee -a ${LOGFILE}

if [[ ! -f $FLE || -z $FLE ]];then #CHECK IF PASSWD FILE EXISTS
	FAIL_MSG="${RED}Credential file is either not READABLE or doesn't EXISTS${NC}"
	fail_func "${FAIL_MSG}"
exit 1
fi

MONGOD_PROC_CNT=$(ps -o args= -C mongod | wc -l) #CHECK NUMBER OF MONGOD PROCESS RUNNING
if ! ((${MONGOD_PROC_CNT}==1)); then 
FAIL_MSG="number of running mongod is not equal to 1. it is : ${RED}${MONGOD_PROC_CNT}${NC}"
fail_func "${FAIL_MSG}"
exit 2
fi

######GET CONFIG FILE##############
MONGOD_PROC_PID=$(ps -o pid= -C mongod) #GET MONGOD PROCESS
MONGOD_CONF=$(ps -o args= -C mongod | tr ' ' '\n' | grep -F '.conf')
if [[ ! ${MONGOD_CONF:0:1} = "/" ]]; then   # CHECK IF MONGOD IS RUNNING WITH RELATIVE PATH CONFIG FILE
echo "Running mongod process config file path is not absolute, trying to locate ${MONGOD_CONF:2}"
if ! command -v locate &> /dev/null ##CHECK IF LOCATE BINARY EXISTS
then
	FAIL_MSG="locate command could not be found"
    fail_func "${FAIL_MSG}"
    exit 3
fi
echo "Updating DB"  | tee -a ${LOGFILE}
updatedb
BASENAME=$(echo ${MONGOD_CONF} | awk -F'/' '{print $NF}' )
REL_MONGOD_CONF_CNT=$(locate ${BASENAME} | wc -l) 
MONGOD_CONF=$(locate ${BASENAME})
if ! ((${REL_MONGOD_CONF_CNT}==1)); then 
FAIL_MSG="Relative Path Config: Number of mongod config files is not equal to ${RED}1${NC}" 
fail_func "${FAIL_MSG}" 
echo Files are ${MONGOD_CONF} | tee -a ${LOGFILE}
exit 4
fi
fi
####################################

[[ ! -d ${BK_DIR} ]] && { echo "${BK_DIR} does not exists " | tee -a ${LOGFILE}; exit 5;} # YOU NEED TO CREATE BK_DIR BEFOREHAND

####################################
###CHECK IF TODAY BACKUP FILE ALREADY EXISTS###
C_DATE_BKP_FILE_CNT=$(find "${BK_DIR}/" -iname "*${CUR_DATE}*" -type d | wc -l)
C_DATE_BKP_EXISTS="N"
if [[ ${C_DATE_BKP_FILE_CNT} -ge 1 ]]; then
FAIL_MSG="Backup for ${CUR_DATE} already exists"
fail_func "${FAIL_MSG}"
exit 6
fi
####################################

###CHECK YESTERDAY FILE###
Y_DATE_BKP_FILE_CNT=$(find "${BK_DIR}/" -iname "*${Y_DATE}*" -type d | wc -l)
Y_DATE_BKP_EXISTS="Y"
if [[ ${Y_DATE_BKP_FILE_CNT} -gt 1 ]]; then
FAIL_MSG="We have 2 backups for yesterday, Please remove the faulty/extra one"
fail_func "${FAIL_MSG}"
exit 7
elif [[ ${Y_DATE_BKP_FILE_CNT} -eq 0 || -z ${Y_DATE_BKP_FILE_CNT} ]]; then
Y_DATE_BKP_EXISTS="N"
echo "No backup for yesterday exists, will not try to tarball it" | tee -a ${LOGFILE}
fi
#------------------------------------END OF CHECKS----------------------------------------------------------------------------------#
#***********************************************************************************************************************************#

#------------------------------------BEGIN OF CREATING TARBALL----------------------------------------------------------------------#
Y_DATE_BKP_FILE=$(find "${BK_DIR}/" -iname "*${Y_DATE}*" -type d )

if [[ ${Y_DATE_BKP_EXISTS} = "Y" ]]; then
echo "Using pigzip to archive and compress ${Y_DATE_BKP_FILE}" 2>&1 | tee -a ${LOGFILE}
tar -cf - ${Y_DATE_BKP_FILE} 2>/dev/null | pigz -9 -k -p 10  > ${Y_DATE_BKP_FILE}.tar.gz
TARBALL_EXIT_CODE=$?
if [[ ${TARBALL_EXIT_CODE} -eq 0 ]]; then
echo "" | tee -a ${LOGFILE}
{ echo "Removing Dir ${Y_DATE_BKP_FILE}" | tee -a ${LOGFILE} ; } && rm -rf ${Y_DATE_BKP_FILE}
echo "Calculating MD5 Sum of ${Y_DATE_BKP_FILE}.tar.gz" | tee -a ${LOGFILE}
md5sum ${Y_DATE_BKP_FILE}.tar.gz > ${Y_DATE_BKP_FILE}_MD5.txt
else
FAIL_MSG="Tarball exit code is non-zero, exiting"
fail_func "${FAIL_MSG}"
exit 8
fi
echo "Tarball ${Y_DATE_BKP_FILE}.tar.gz Created" | tee -a ${LOGFILE}
fi
#tar --use-compress-program="pigz -k -9 -p 20" -cf ${Y_DATE_BKP_FILE}.tar.gz ${Y_DATE_BKP_FILE}     #DID NOT WORK

#************************************************************************
# to decompress later ==> tar --use-compress-program=pigz -xvf FILENAME
#************************************************************************

#------------------------------------END OF CREATING TARBALL------------------------------------------------------------------------#
#***********************************************************************************************************************************#

#------------------------------------BEGIN OF SPACE CHECK---------------------------------------------------------------------------#
DATADIR=$(sed -n  '/^[[:blank:]]*#/d;s/#.*//;/dbPath.*/p' ${MONGOD_CONF} | awk -F ':' '{print $2}')
DATADIR_SIZE_IN_MB=$(bc -l <<< "scale=0; $(du -sb ${DATADIR} | awk '{print $1}')/1024/1024")
#PCENT_USED_BK_DIR=$(df --output=pcent  ${BK_DIR} | tail -1 | sed 's/%//')
BK_DIR_REM_SIZE_IN_MB=$(df --output=avail --block-size=1m  ${BK_DIR} | tail -1)
BK_DIR_TOT_SIZE_IN_MB=$(df --output=size --block-size=1m  ${BK_DIR} | tail -1)
BK_DIR_REM_AFTER_BK_MB=$((${BK_DIR_REM_SIZE_IN_MB}-${DATADIR_SIZE_IN_MB}))

if [[ ${BK_DIR_REM_AFTER_BK_MB} -lt $( bc -l <<<"scale=0; ${BK_DIR_TOT_SIZE_IN_MB} * 0.05/1 ") ]]; then 
FAIL_MSG="taking backup will make ${BK_DIR} remaining space less than 5%,skipping backup"
fail_func "${FAIL_MSG}"
exit 9
fi
#------------------------------------END OF SPACE CHECK-----------------------------------------------------------------------------#
#***********************************************************************************************************************************#

#------------------------------------BEGIN OF MONGODUMP-----------------------------------------------------------------------------#

###mongodump connection info###
MONGO_PORT=$(echo $(sed -n  '/^[[:blank:]]*#/d;s/#.*//;/port.*/p' ${MONGOD_CONF} | awk -F ':' '{print $2}'))
USR=$(awk 'FNR == 1 {print}' $FLE | base64 -d)
PASSWD=$(awk 'FNR == 2 {print}' $FLE | base64 -d)
####################################
echo "" | tee -a ${LOGFILE}
echo "**********************************************************" | tee -a ${LOGFILE}
echo "STARTING BACKUP - " `date +%Y-%m-%d---%T` | tee -a ${LOGFILE}
echo "Backup Dir: ${BK_DIR}" | tee -a ${LOGFILE}
echo "Backup File: ${BKP_FILE}" | tee -a ${LOGFILE}
printf "\n" >> ${LOGFILE}

#****Below method is ineffecient
#mongodump --host=${HOST_IP} --port=${MONGO_PORT} --username=$USR --password=$PASSWD  --archive  2>>$LOGFILE | tee -a ${BKP_FILE}.archive |  pigz -9 -p 25 > {BKP_FILE}.gz
#MONGO_DMP_RES=${PIPESTATUS[0]}
#****

mongodump --host=${HOST_IP} --port=${MONGO_PORT} --username=${USR} --password=${PASSWD} -o ${BKP_FILE} 3>&1 1>&2 2>&3 | tee -a ${LOGFILE}
MONGO_DMP_RES=$?

if [[ ! ${MONGO_DMP_RES} -eq 0 ]]; then
   FAIL_MSG="Mongodump failed at ${CUR_DATE} in $(hostname)"
   fail_func "${FAIL_MSG}"
   exit 10
fi

DFDATA=$(df -Ph ${BK_DIR} | grep -Po '\d+(?=%)')
BKP_FILE_SIZE_IN_GB=$(bc -l <<< "scale=0; $(du -sb ${BKP_FILE} | awk '{print $1}')/1024/1024/1024")
echo "BK File size is ${BKP_FILE_SIZE_IN_GB}GB" | tee -a ${LOGFILE}
echo "Backup done - " `date +%Y-%m-%d---%T` | tee -a ${LOGFILE}

#------------------------------------END OF MONGODUMP-------------------------------------------------------------------------------#
#***********************************************************************************************************************************#

#------------------------------------BEGIN OF REMOVAL-------------------------------------------------------------------------------#

#########REMOVAL##########
find $BK_DIR -iname "mongo_backup_daily_$(hostname)*.tar.gz" -type f -mtime +${BACKUP_RETENTION_DAYS_DAILY} -exec rm -v {} +  2>&1 | tee -a ${LOGFILE} #=> DAILY RETENTION
find $BK_DIR -iname "mongo_backup_weekly_$(hostname)*.tar.gz" -type f -mtime +${BACKUP_RETENTION_DAYS_WEEKLY} -exec rm -v {} +  2>&1 | tee -a ${LOGFILE} #=> WEEKLY RETENTION
find $BK_DIR -iname "mongo_backup_monthly_$(hostname)*.tar.gz" -type f -mtime +${BACKUP_RETENTION_DAYS_MONTHLY} -exec rm -v {} +  2>&1 | tee -a ${LOGFILE} #=> MONTHLY RETENTION

find $BK_DIR -iname "mongo_backup_monthly_$(hostname)*.log" -type f -mtime +${BACKUP_RETENTION_DAYS_LOGS} -exec rm -v {} +  2>&1 | tee -a ${LOGFILE} #=> LOG RETENTION
find $BK_DIR -iname "mongo_backup_monthly_$(hostname)*.txt" -type f -mtime +${BACKUP_RETENTION_DAYS_LOGS} -exec rm -v {} +  2>&1 | tee -a ${LOGFILE} #=> MD5 RETENTION
##########################
echo "" | tee -a ${LOGFILE}
echo "Remove Done" | tee -a ${LOGFILE}

secs=$SECONDS
hrs=$(( secs/3600 )); mins=$(( (secs-hrs*3600)/60 )); secs=$(( secs-hrs*3600-mins*60 ))
formatted_time=$(printf 'Time spent: %02d:%02d:%02d' $hrs $mins $secs)
echo -e ${formatted_time} | tee -a ${LOGFILE}
RC_DATE=$(date +%Y%m%d-%H:%M%:S)
#----send success-------
#RC_HOOK_SUCESS='{"alias":"Mongo Post","emoji":":monkey:","text":'${RC_SUCCESS_MSG}'. \n Date: '${RC_DATE}'UTC \n Service: Superpay Prod \n HostIP: '${HOST_IP}' FreeSpace: '${DFBK_AFTERBK}'G \n ElapsedTime:'${formatted_time}'"}'
RC_HOOK_SUCESS='{"alertname":"Database-Backup","emoji":":raccoon:","text":"Message Type: '${ISEVERITY}' \n  Message Title: '${TITLE}' \n Server IP: '${HOST_IP}' \n Server Name: '$(hostname)' \n Description:\n '${SDESC}' \n Disk Used: '${DFDATA}'% \n Backup Size: '${BKP_FILE_SIZE_IN_GB}'G \n ElapsedTime: '${formatted_time}'"}'
curl -X POST -H "Content-type:application/json" --data "${RC_HOOK_SUCESS}" ${RC_WEBHOOK}
#----end send success---

echo "END - " `date +%Y-%m-%d---%T` | tee -a ${LOGFILE}
echo "**********************************************************" | tee -a ${LOGFILE}

#------------------------------------END OF REMOVAL-----------------------------------------------------------------------------#