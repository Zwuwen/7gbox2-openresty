--Initialization shared memory

--daemon thread function
local g_sql_app = require("common.sql.g_orm_info_M")
local g_redis_app = require("common.redis.g_redis_M")
local g_udp = require("common.udp.udpcli_M")
--local g_http_app = require("common.http.myhttp_M")
--start postgresql connect
ngx.log(ngx.ERR,"my sql orm verion:"..g_sql_app["version"])
local result = g_sql_app.open_db()

if result == false and result ~= nil then
	ngx.log(ngx.ERR,"init db failure")
	return
end


----
