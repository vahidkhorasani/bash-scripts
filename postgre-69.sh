#!/bin/bash
#-------------------------------------------
echo "START - " `date +%Y-%m-%d---%T`
#-------------------------------------------

v_date_1=`date --date="1 day ago" +%Y-%m-%d`
v_archive_name=$v_date_1.tar.gz
BK_DIR="/mnt/STORAGE/backup/archive/"
tar cfzP $BK_DIR$v_archive_name $BK_DIR$v_date_1

echo "Archive Done"

rm -rf $BK_DIR$v_date_1

echo "Remove Done"

##-------------------------------------------
echo "move done - " `date +%Y-%m-%d---%T`
##-------------------------------------------
find $BK_DIR -mtime +30 -type f -exec rm -rf {} \;
##-------------------------------------------
echo "remove done - " `date +%Y-%m-%d---%T`
##-------------------------------------------

BK_DIR_DATE="/mnt/STORAGE/backup/archive/`date +%Y-%m-%d`/"
BK_NAME="postgres_alldb_`date +%Y-%m-%d`.sql"
mkdir $BK_DIR_DATE

pg_dumpall > $BK_DIR_DATE$BK_NAME

#-------------------------------------------
echo "backup done - " `date +%Y-%m-%d---%T`
#-------------------------------------------

##-------------------------------------------
echo "END - " `date +%Y-%m-%d---%T`
##-------------------------------------------

#SMS
SMSURL="192.168.70.90:6630"
USER="d2vps"
PASS="mb88ile"
MOBILE_NUMBERS="    
09991332754
"

# SMS
for MOBILE in $MOBILE_NUMBERS
do
	MESSAGE="%20AP_BK_DONE%2071.69" && \
	curl --connect-timeout 10 -X GET "http://$SMSURL/devopsmsgs.aspx?mob=${MOBILE}&usr=${USER}&pwd=${PASS}&msg=${MESSAGE}"
done



