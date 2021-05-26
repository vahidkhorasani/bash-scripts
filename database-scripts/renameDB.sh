#!/bin/sh
srctables=""
user=""
password=""
host=""
oldDB=""
newDB=""
mysql -u ${user} -h ${host} -p${password} ${oldDB} -sNe "SHOW TABLES;" > ${srctables}
mysql -u ${user} -h ${host} -p${password} -e "CREATE DATABASE ${newDB} CHARSET='utf8' COLLATE='utf8_unicode_ci';" 

echo "Here is the size of databases before renaming: "
echo "-----------------------------------------------"
mysql -u ${user} -h ${host} -p${password} -e 'SELECT table_schema AS "Database", ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS "Size (MB)" FROM information_schema.TABLES GROUP BY table_schema;'
while read line 
do
mysql -u ${user} -h ${host} -p${password} ${oldDB} -sNe "RENAME TABLE ${oldDB}.${line} to ${newDB}.${line};"
done < ${srctables}

echo "The ${oldDB} tables are: "
echo "--------------------------"
mysql -u ${user} -h ${host} -p${password} ${oldDB} -sNe "SHOW TABLES;"
echo "--------------------------"
echo "The ${newDB} tables are: "
echo "-------------------------"
mysql -u ${user} -h ${host} -p${password} ${newDB} -sNe "SHOW TABLES;"
echo "-------------------------"
echo "Now the size of databases are as follow: "
mysql -u ${user} -h ${host} -p${password} -e 'SELECT table_schema AS "Database", ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS "Size (MB)" FROM information_schema.TABLES GROUP BY table_schema;'
