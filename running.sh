#!/bin/bash

PWD=`pwd`
echo $PWD

CONF=$PWD/7g_nginx_gw.conf
NGINX=/usr/sbin/nginx
PRIFIX=/userdata/7g-box/openresty-svr/

mkdir -p /data/logs/nginx
mkdir -p /var/log/nginx /var/tmp/nginx

case "$1" in
  start)
        echo "Starting nginx..."
        echo "config file: $CONF"
        $NGINX -c $CONF -p $PWD
        ;;
  stop)
        echo "Stopping nginx..."
        killall nginx
        sleep 1
        ;;
  reload|force-reload)
        echo "Reloading nginx configuration..."
        "$NGINX" -s reload -c $CONF -p $PWD
        ;;
  restart)
        "$0" stop
        sleep 1 # Prevent race condition: ensure nginx stops before start.
        "$0" start
        ;;
  *)
        echo "Usage: $0 {start|stop|restart|reload|force-reload}"
        exit 1
esac
