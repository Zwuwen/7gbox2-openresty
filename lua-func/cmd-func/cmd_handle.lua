--alone function
--restful parsing parameters
--version/rule/rule_uuid
--load module
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_cmd_sync = require("alone-func.cmd_sync")
local g_micro = require("cmd-func.cmd_micro")

-----------------cmd get method---------------------
local function get_method()
	ngx.req.read_body()
		local request_body = ngx.req.get_body_data()
	local json_body = cjson.decode(request_body)
end

-----------------cmd update method-----------------
local function update_method()
	--get request_body
	ngx.req.read_body()
	local request_body = ngx.req.get_body_data()
	local json_body = cjson.decode(request_body)
	if json_body["Method"] == "ResetToAuto" then
		--命令切换自动
		g_cmd_sync.delete_cmd_from_ruletable(json_body["DevType"],json_body["DevId"],json_body["DevChannel"],json_body["In"]["Method"])
		local json_str = '{\n\"code\":200,\n \"msg\":\"sucess"\n\"payload\":{}\n}'
		ngx.say(json_str)
	elseif json_body["Method"] == "CancleLinkageRule" then
		local res,status = g_micro.micro_delete("RuleEngine",request_body)
		ngx.say(res)
	else
		--转发命令到微服务
		local res,status = g_micro.micro_post(json_body["DevType"],request_body)
		if status == true then
			--命令切换手动
			g_cmd_sync.insert_cmd_to_ruletable(json_body["DevType"],json_body["DevId"],json_body["DevChannel"],json_body["Method"])
		end
		ngx.say(res)
	end
end

-----------------cmd post method---------------------
local function create_method()
	--g_event_report
end

-----------------cmd delete method-----------------
local function delete_method()

end

-------main function------------

local request_method = ngx.var.request_method
if request_method == "GET" then
	get_method()
elseif request_method == "POST" then
	create_method()
elseif request_method == "PUT" then
	update_method()
elseif request_method == "DELETE" then
	delete_method()
end
g_sql_app.close_db()

