#!/bin/bash

MYSQLDUMP=$(which mysqldump)
DUMPDIR="$(dirname "$(realpath "$0")")"
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
     -o outputdir - output directory for the MySQL dump file
                    (default: $DUMPDIR) 

EXAMPLE
    $(basename $0) -h 1.2.3.4 -d zabbixdb -u zabbix -p test
    $(basename $0) -d zabbixdb -u zabbix -p - -o /tmp
EOF
    exit 1
fi  

#
# PARSE COMMAND LINE ARGUMENTS
#
while getopts ":h:d:u:p:o:" opt; do
  case $opt in
    h)  DBHOST="$OPTARG" ;;
    d)  DBNAME="$OPTARG" ;;
    u)  DBUSER="$OPTARG" ;;
    p)  DBPASS="$OPTARG" ;;
    o)  DUMPDIR="$OPTARG" ;;
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
MYSQL_DUMP="${MYSQLDUMP} --single-transaction $MYSQL_CONN"

DUMPFILEBASE="zabbix_$(date +%Y%m%d-%H%M)_full.sql"
DUMPFILE="${DUMPDIR}/${DUMPFILEBASE}"

#
# CONFIG DUMP
#
cat <<EOF
Configuration:
 - host:     $DBHOST
 - database: $DBNAME
 - user:     $DBUSER
EOF

#
# BACKUP
#
mkdir -p "${DUMPDIR}"
echo "Dump database to ${DUMPFILE}..."
$MYSQL_DUMP > "${DUMPFILE}"

echo 
echo "Compressing dump file..."
gzip -f "${DUMPFILE}"
if [ $? -ne 0 ]; then
    echo -e "\nERROR: Could not compress backup file, see previous messages" >&2
    exit 1
fi

echo
echo "Rotate backup copy..."
find "${DUMPDIR}/" -maxdepth 1 -mtime +10 -type f -exec rm -rv {} \;
if [ $? -ne 0 ]; then
    echo -e "\nERROR: Could not rotate backup file, see previous messages" >&2
    exit 1
fi

echo -e "\nBackup Completed:\n${DUMPFILE}.gz"
exit