#!/bin/bash
while :
do
hour=`date "+%H"`
minute=`date "+%M"`
second=`date "+%S"`

left_hour=$((24-$hour-1))
left_minute=$((60-$minute-1))
left_second=$((60-$second-1))

left_time=$(($left_hour*3600+$left_minute*60+$left_second))
sleep $left_time

mv /userdata/logs/nginx/openresty.log /userdata/logs/nginx/openresty-$(date +"%Y%m%d").log
cd /usr/local/7g-box/openresty-svr/
running.sh reload
find /userdata/logs/nginx -mtime +7 -type f -name \*.log | xargs rm -f

sleep 60
done