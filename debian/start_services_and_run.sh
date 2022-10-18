#!/bin/sh
#
# start_services_and_run.sh - starts various services before
# auto_installing and running test suites. It is inspired by
# debian/test_mysql.sh from libdbi-drivers source package.

# Currently it starts mysqld, redis and memcached services


set -e

MEMCACHED_USER=nobody
PIDFILE=/tmp/memcached.pid

MYTEMP_DIR=`mktemp -d`
ME=`whoami`

export MYSQL_UNIX_PORT=${MYTEMP_DIR}/mysql.sock
DO_MYSQL_USER=root
DO_MYSQL_PASS=
DO_MYSQL_DBNAME=test
DO_MYSQL_DATABASE=/${DO_MYSQL_DBNAME}

# Start memcached
/usr/bin/memcached -d -u ${MEMCACHED_USER} -P ${PIDFILE}

# Start mysqld
mysql_install_db --no-defaults --datadir=${MYTEMP_DIR} --force --skip-name-resolve --user=${DO_MYSQL_USER}
cat >${MYTEMP_DIR}/init.sql <<EOT
UPDATE mysql.user SET plugin = "";
FLUSH PRIVILEGES;
EOT
/usr/sbin/mysqld --no-defaults --user=${DO_MYSQL_USER} --socket=${MYSQL_UNIX_PORT} --datadir=${MYTEMP_DIR} --skip-networking --init-file=${MYTEMP_DIR}/init.sql &
echo -n pinging mysqld.
attempts=0
while ! /usr/bin/mysqladmin --user=${DO_MYSQL_USER} --socket=${MYSQL_UNIX_PORT} ping ; do
  sleep 3
  attempts=$((attempts+1))
  if [ ${attempts} -gt 10 ] ; then
    echo "skipping test, mysql server could not be contacted after 30 seconds"
    exit 0
  fi
done
#mysql --socket=${MYSQL_UNIX_PORT} --execute "CREATE DATABASE ${DO_MYSQL_DBNAME};"
mysql --user=${DO_MYSQL_USER} --socket=${MYSQL_UNIX_PORT} --execute "GRANT ALL PRIVILEGES ON ${DO_MYSQL_DBNAME}.* TO '${DO_MYSQL_USER}'@'localhost' IDENTIFIED BY '${DO_MYSQL_PASS}';"

# Create database for activerecord tests
mysql --user=${DO_MYSQL_USER} --socket=${MYSQL_UNIX_PORT} --execute "create database widgets;"
mysql --user=${DO_MYSQL_USER} --socket=${MYSQL_UNIX_PORT} --execute "create table widgets.widgets (id INT NOT NULL AUTO_INCREMENT, title varchar(255), PRIMARY KEY (id) );"

# Start redis server
redis-server --daemonize yes

"$@"

# Drop databases
mysql --user=${DO_MYSQL_USER} --socket=${MYSQL_UNIX_PORT} --execute "drop database widgets;"

# Stop mysqld
/usr/bin/mysqladmin --user=${DO_MYSQL_USER} --socket=${MYSQL_UNIX_PORT} shutdown
rm -rf ${MYTEMP_DIR}

# Stop memcached and cleanup pid file
pkill memcached

# Stop redis server
pkill redis-server
