#!/bin/bash

#-------------------------------------------
echo "START - " `date +%Y-%m-%d---%T`
#-------------------------------------------

v_date_1=`date --date="1 day ago" +%Y-%m-%d`
v_archive_name=$v_date_1.tar.gz
BK_DIR="/mnt/postgres-bk/postgrs_archive/"
sudo tar cfzP $BK_DIR$v_archive_name $BK_DIR$v_date_1

echo "Archive Done"

sudo rm -rf $BK_DIR$v_date_1

echo "Remove Done"

#find /var/lib/postgresql_backup/ -type f \( -name '*.gz'  \) -exec mv {} /mnt/postgres-bk/postgrs_archive/ \;
##-------------------------------------------
echo "move done - " `date +%Y-%m-%d---%T`
##-------------------------------------------
find $BK_DIR -mtime +15 -type f -exec rm -rf {} \;
##-------------------------------------------
echo "remove done - " `date +%Y-%m-%d---%T`
##-------------------------------------------

BK_DIR_DATE="/mnt/postgres-bk/postgrs_archive/`date +%Y-%m-%d`/"
BK_NAME="postgres_alldb_`date +%Y-%m-%d`.sql"
sudo mkdir $BK_DIR_DATE

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
09035862898
"
NAME="Postgres-192.168.71.175"
# SMS
DF=$(df -h / | awk '/\/dev\//{printf("%d\n",$5)}')

for MOBILE in $MOBILE_NUMBERS
do
	MESSAGE="%20AP-175-POSTGRES-BK-$DF%used" && \
	curl --connect-timeout 10 -X GET "http://$SMSURL/devopsmsgs.aspx?mob=${MOBILE}&usr=${USER}&pwd=${PASS}&msg=${MESSAGE}"
done


