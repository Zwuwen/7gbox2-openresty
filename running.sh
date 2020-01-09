#!/bin/bash

PWD=`pwd`
echo $PWD

CONF=$PWD/7g_nginx_gw.conf
NGINX=/usr/sbin/nginx
PRIFIX=/userdata/7g-box/openresty-svr/


rm -rf logs/*
killall nginx

if [ $# -ge 1 ]
then
	echo "restart"
	if [ $1 == "restart" ]
	then
		echo "config file: $CONF"
		echo "currdir: $PWD"
		$NGINX -c $CONF -s reload -p $PRIFIX
		echo -e "\033[32m openresty restart complete \033[0m"
	fi
else

	if [ -e $CONF ]
	then
		killall nginx
		sleep 1
		echo "config file: $CONF"
		$NGINX -c $CONF -p $PWD
		echo -e "\033[32m running openresty complete \033[0m"

	else
		echo -e "\033[31m running openresty failure\033[0m"
	fi

fi
