#!/bin/bash
mv /userdata/logs/nginx/openresty.log /userdata/logs/nginx/openresty-$(date +"%Y%m%d").log
find /userdata/logs/nginx -mtime +7 -type f -name \*.log | xargs rm -f
echo > /userdata/logs/nginx/openresty.log