--alone function
--restful parsing parameters
--version/rule/rule_uuid
--load module
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_micro = require("cmd-func.cmd_micro")
local g_event_report = require("event-func.event_report")

-----------------cmd get method---------------------
local function get_method()
	ngx.req.read_body()
		local request_body = ngx.req.get_body_data()
	local json_body = cjson.decode(request_body)
end

-----------------cmd update method-----------------
local function creat_respone_message(result,descrip)
	local message={}
	message["Result"] = result
	message["Descrip"] = descrip
	return cjson.encode(message)
end

local function message_pack(json_body,res)
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
end

local function attribute_change_message(dev_type,dev_id,channel_id,status)
	local json_dict = {}
	json_dict["Token"] = "7GBox"
	json_dict["Event"] = "StatusUpload"
	local dev_dict = {}
	dev_dict["DevType"] = dev_type
	dev_dict["DevId"] = dev_id
	local attr = {}
	attr["AutoMode"] = status
	dev_dict["Attribute"] = attr
	local dev_list = {dev_dict}
	local payload = {}
	payload["Devices"] = dev_list
	json_dict["Payload"] = payload
	return json_dict
end

local function update_method()
	--get request_body
	ngx.req.read_body()
	local request_body = ngx.req.get_body_data()
	local json_body = cjson.decode(request_body)
	if json_body["Method"] == "ResetToAuto" then
		--命令切换自动
		local update_json = {}
		update_json["auto_mode"] = 1
		g_sql_app.update_dev_status_tbl(json_body["DevId"],update_json)
		local res = creat_respone_message(0,"Success")
		message_pack(json_body,res)
		local message = attribute_change_message(json_body["DevType"],json_body["DevId"],json_body["DevChannel"],1)
		g_event_report.attribute_change(message)
	elseif json_body["Method"] == "ResetToManual" then
		--命令切换手动
		local update_json = {}
		update_json["auto_mode"] = 0
		g_sql_app.update_dev_status_tbl(json_body["DevId"],update_json)
		local res = creat_respone_message(0,"Success")
		message_pack(json_body,res)
		local message = attribute_change_message(json_body["DevType"],json_body["DevId"],json_body["DevChannel"],0)
		g_event_report.attribute_change(message)
	elseif json_body["Method"] == "CancleLinkageRule" then
		local res,status = g_micro.micro_delete("RuleEngine",request_body)
		message_pack(json_body,res)
	else
		--查询是否处于自动或者联动
		result = g_sql_app.query_dev_status_tbl(json_body["DevId"])
		if result[1]["auto_mode"] == 0 and result[1]["linkage_rule"] == 0 then
			--转发命令到微服务
			if json_body["DevType"]~=nil and json_body["DevId"]~=nil and json_body["DevChannel"]~=nil and json_body["Method"]~=nil then
				local res,status = g_micro.micro_post(json_body["DevType"],request_body)
				message_pack(json_body,res)
			else
				local res = creat_respone_message(400,"parameter is err")
				message_pack(json_body,res)
			end
		else
			local res = creat_respone_message(400,"device is auto mode")
			message_pack(json_body,res)
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


