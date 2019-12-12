--alone function
--restful parsing parameters
--version/rule/rule_uuid

--const define
local uri_len = 23
local type_len = 4
local cmd_type = "9001"
local cmd_len = 3

--load module
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_exec_rule = require("alone-func.exec_rule")
local g_cmd_sync = require("alone-func.cmd_sync")
local g_micro = require("cmd-func.cmd_micro")


-----------------cmd get method---------------------
local function get_device_message_method(dev_id)
	local res,err = g_sql_app.query_dev_status_tbl(dev_id)
	ngx.log(ngx.ERR,"res: ",cjson.encode(res))
	local respone = {}
	for key, value in ipairs(res) do
		respone["DevType"] = "InfoScreen"
		respone["DevId"] = dev_id
		local attribute = cjson.decode(value["attribute"])
		local channel = attribute["Channel"]
		local len = table.getn(channel)
		respone["ChannelNum"] = len
		respone["Channel"] = channel
	end
	ngx.say(cjson.encode(respone))
end

local function get_method()
	ngx.req.read_body()
		local request_body = ngx.req.get_body_data()
	local json_body = cjson.decode(request_body)
	local dev_id = json_body["DevId"]
	get_device_message_method(dev_id)
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

