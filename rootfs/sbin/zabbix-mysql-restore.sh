#!/bin/bash

MYSQL=$(which mysql)
AWK=$(which awk)
GREP=$(which grep)
GZIP=$(which gzip)
DUMPFILE="$(dirname "$(realpath "$0")")\zabbix.sql.gz"
DBHOST="127.0.0.1"
DBNAME="zabbix"
DBUSER="zabbix"
DBPASS=""

#
# SHOW HELP
#
if [ -z "$1" ]; then
    cat <<EOF
USAGE
    $(basename $0) [options]
    
OPTIONS
     -h host      - hostname/IP of MySQL server (default: $DBHOST)
     -d database  - Zabbix database name (default: $DBNAME)
     -u user      - MySQL user to access Zabbix database (default: $DBUSER)
     -p password  - MySQL user password (specify "-" for a prompt)
     -i inputfile - input Gzip MySQL dump file
                    (default: $DUMPFILE) 

EXAMPLE
    $(basename $0) -h 1.2.3.4 -d zabbixdb -u zabbix -p test
    $(basename $0) -d zabbixdb -u zabbix -p - -i /backup/zabbix_full.sql.gz
EOF
    exit 1
fi  

#
# PARSE COMMAND LINE ARGUMENTS
#
while getopts ":h:d:u:p:i:" opt; do
  case $opt in
    h)  DBHOST="$OPTARG" ;;
    d)  DBNAME="$OPTARG" ;;
    u)  DBUSER="$OPTARG" ;;
    p)  DBPASS="$OPTARG" ;;
    i)  DUMPFILE="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :)  echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
  esac
done

if [ "$DBPASS" = "" ]; then
    echo "No password given" >&2
    exit 1
fi

if [ "$DBPASS" = "-" ]; then
    read -s -p "Enter MySQL password for user '$DBUSER' (input will be hidden): " DBPASS
    echo ""
fi

#
# CONSTANTS
#
MYSQL_CONN="-h ${DBHOST} -u ${DBUSER} -p${DBPASS} ${DBNAME}"
MYSQL_EXECUTOR="$MYSQL $MYSQL_CONN"

#
# CONFIG DUMP
#
cat <<EOF
Configuration:
 - host:     $DBHOST
 - database: $DBNAME
 - user:     $DBUSER
EOF

if [[ -f ${DUMPFILE} ]]; then
    TABLES=$($MYSQL_EXECUTOR -e 'show tables' | $AWK '{print $1}' | $GREP -v '^Tables' )
    for t in $TABLES
    do
        echo "=> Deleting $t table from zabbix database..."
        $MYSQL_EXECUTOR -e "SET foreign_key_checks = 0;drop table $t;SET foreign_key_checks = 1;"
    done
    
    echo "=> Restore zabbix database..."    
    echo "=> Add database schema..."
    zabbix_mysql_v="/usr/share/zabbix/database/mysql"
    $MYSQL_EXECUTOR < "${zabbix_mysql_v}/schema.sql"
    $MYSQL_EXECUTOR < "${zabbix_mysql_v}/images.sql"
    
    echo "=> Unzip MYSQL dump file..."
    $GZIP -d ${DUMPFILE}
    
    echo "=> Restore database from dump..."
    $MYSQL_EXECUTOR < ${DUMPFILE%.*}
    
    echo "=> Gzip MYSQL dump file..."
    $GZIP -9 -f ${DUMPFILE%.*}
    
    echo "=> Done!"
    exit
else
    echo "=> ${DUMPFILE} not found!"
    exit 1
fi
