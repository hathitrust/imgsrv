#! /bin/bash

#/usr/sbin/apache2ctl -D FOREGROUND

# Apache gets grumpy about PID files pre-existing
if [ ! -d /var/run/apache2 ]
then
  mkdir -p /var/run/apache2
fi

rm -f /var/run/apache2/apache2*.pid

source /etc/apache2/envvars
ln -sf /dev/stdout $APACHE_LOG_DIR/access.log && ln -sf /dev/stderr $APACHE_LOG_DIR/error.log

exec apache2 -DFOREGROUND 