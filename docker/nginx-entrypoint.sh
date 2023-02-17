#!/bin/sh

/etc/init.d/fcgiwrap start
chmod 766 /var/run/fcgiwrap.socket
ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log
nginx -g "daemon off;"