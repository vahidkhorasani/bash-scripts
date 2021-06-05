#!/bin/sh

SRC_TABLE="/tmp/tables"
USR="Your username goes here"
PASSWD="Your password goes here"
HOST="Your Database Hostname or IP address goes here"
PORT="Your Databse port number"
OLD_DB="Your DB name"
NEW_DB="Your DB new name"

mysql -u ${USR} -h ${HOST}:${PORT} -p${PASSWD} ${OLD_DB} -sNe "SHOW TABLES;" > ${SRC_TABLE}
mysql -u ${USR} -h ${HOST}:${PORT} -p${PASSWD} -e "CREATE DATABASE ${NEW_DB} CHARSET='utf8' COLLATE='utf8_unicode_ci';" 

# Checking Database size before any changes
echo "Here is the size of databases before renaming: "
echo "-----------------------------------------------"
mysql -u ${USR} -h ${HOST}:${PORT} -p${PASSWD} -e 'SELECT table_schema AS "Database", ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS "Size (MB)" FROM information_schema.TABLES GROUP BY table_schema;'
while read line 
do
mysql -u ${USR} -h ${HOST}:${PORT} -p${PASSWD} ${OLD_DB} -sNe "RENAME TABLE ${OLD_DB}.${line} to ${NEW_DB}.${line};"
done < ${SRC_TABLE}

echo "The ${OLD_DB} tables are: "
echo "--------------------------"
mysql -u ${USR} -h ${HOST}:${PORT} -p${PASSWD} ${OLD_DB} -sNe "SHOW TABLES;"
echo "--------------------------"
echo "The ${NEW_DB} tables are: "
echo "-------------------------"
mysql -u ${USR} -h ${HOST}:${PORT} -p${PASSWD} ${NEW_DB} -sNe "SHOW TABLES;"
echo "-------------------------"

# Checking Database size after renaming
echo "Now the size of databases are as follow: "
mysql -u ${USR} -h ${HOST}:${PORT} -p${PASSWD} -e 'SELECT table_schema AS "Database", ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS "Size (MB)" FROM information_schema.TABLES GROUP BY table_schema;'
