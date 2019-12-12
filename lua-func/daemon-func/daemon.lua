daemon_M = {version = "v1.0.1"}

local pri_level = 10

--load module
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")

function daemon_M.heartbeat()

end

function daemon_M.rule_running()
	local i = 1
	while true
	do
		if i > pri_level then
			break
		end
		--get priority
		local res,err = g_sql_app.query_rule_tbl_by_priority(i)
		if err then
			ngx.log(ngx.ERR,"rule table data error")
			return
		end
		
		i = i+1
	end
end

function daemon_M.event()

end

return daemon_M
