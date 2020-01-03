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
		if g_cmd_sync.delete_cmd_from_ruletable(request_body) == true then
			local json_str = '{\n\"Code\":200,\n \"Msg\":\"Sucess"\n\"Payload\":{}\n}'
			ngx.say(json_str)
		else
			local json_str = '{\n\"Code\":400,\n \"Msg\":\"Fail"\n\"Payload\":{}\n}'
			ngx.say(json_str)
		end
		
	elseif json_body["Method"] == "CancleLinkageRule" then
		local res,status = g_micro.micro_delete("RuleEngine",request_body)
		ngx.say(res)
	else
		--转发命令到微服务
		if json_body["DevType"]~=nil and json_body["DevId"]~=nil and json_body["DevChannel"]~=nil and json_body["Method"]~=nil then
			local res,status = g_micro.micro_post(json_body["DevType"],request_body)
			if json_body["MsgId"]~=nil then
				local return_json = cjson.decode(res)
				return_json["MsgId"] = json_body["MsgId"]
				local gw = g_sql_app.query_dev_info_tbl(0)
				return_json["GW"] = gw[1]["sn"]
				return_json["Event"] = "ReqStsUpload"
				local res_str = cjson.encode(return_json)
				ngx.say(res_str)
			else
				ngx.say(res)
			end
		else
			local json_str = '{\n\"Code\":400,\n \"Msg\":\"Parameter is err!"\n\"Payload\":{}\n}'
			ngx.say(json_str)
		end
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


