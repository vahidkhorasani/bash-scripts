#!/bin/bash

#-------------------------------------------
echo "START - " `date +%Y-%m-%d---%T`
#-------------------------------------------

v_date_1=`date --date="1 day ago" +%Y-%m-%d`
echo $v_date_1
cd /data/backup/all_dbs/
v_archive_name=$v_date_1.tar.gz

echo $v_archive_name

#sudo tar cfzP $v_archive_name /mnt/data/backup/all_dbs/$v_date_1

sudo tar --use-compress-program="pigz -k -9 -p 20" -cf $v_archive_name /data/backup/all_dbs/$v_date_1

echo "Archive Done"

cd /data/backup/all_dbs/

sudo rm -rf $v_date_1

echo "Remove Done $v_date_1"

find /data/backup/all_dbs/ -type f \( -name '*.gz'  \) -exec mv {} /data/backup/all_dbs/archive \;
#-------------------------------------------
echo "move done - " `date +%Y-%m-%d---%T`
#-------------------------------------------
find /data/backup/all_dbs/archive/ -mtime +4 -type f -exec rm -rf {} \;
#-------------------------------------------
echo "remove done - " `date +%Y-%m-%d---%T`
#-------------------------------------------


v_date=`date --date="0 day ago" +%Y-%m-%d`

DIR="/data/backup/all_dbs/`date +%Y-%m-%d`"
echo $DIR
mkdir $DIR
cd $DIR


#mongo --port 27017  --authenticationDatabase "admin" -u "b_teymoori" -p "vpqgZdjdkfTLY3Uh"
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=admin
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_auth_log
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_credit_portal_log
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_digital_banking_neshanbank
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_flight_ticket
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_mobile_backup
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_payment_mobapp_credit
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_payment_mobapp_direct_debit
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_payment_mobapp_micropayment
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_platform_third_party_api_gateway
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_portal_core
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_portals_portal_asan_ticket
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_pwa_gw
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_tourism_bus_ticket
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_tourism_engine_log
mongodump --host=localhost --port=27017 --username=b_teymoori --password=vpqgZdjdkfTLY3Uh --authenticationDatabase=admin --db=ap_tourism_train_ticket               

#-------------------------------------------
echo "backup done - " `date +%Y-%m-%d---%T`
#-------------------------------------------
echo "END - " `date +%Y-%m-%d---%T`
#-------------------------------------------

#SMS
SMSURL="192.168.70.90:6630"
USER="d2vps"
PASS="mb88ile"
MOBILE_NUMBERS="
09035862898
"
NAME="Mongo-192.168.71.50"
DF=$(df -h /data | awk '/\/dev\//{printf("%d\n",$5)}')
# SMS
for MOBILE in $MOBILE_NUMBERS
do
	MESSAGE="%20AP-49-MONGO-BK-$DF%used" && \
	curl --connect-timeout 10 -X GET "http://$SMSURL/devopsmsgs.aspx?mob=${MOBILE}&usr=${USER}&pwd=${PASS}&msg=${MESSAGE}"
done

