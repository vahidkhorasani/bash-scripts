#!/bin/bash

USR="Your Username goes here"
PASSWD="Your Password goes here"
HOST="Your Hostname or IP Address goes here"
PORT="Your database port number goes here"

mysql -u ${USR} -p${PASSWD} -h ${HOST}:${PORT} -e 'SELECT table_schema AS "Database", ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS "Size (MB)" FROM information_schema.TABLES GROUP BY table_schema;'
