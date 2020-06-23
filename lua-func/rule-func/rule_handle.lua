local cjson = require("cjson")
local g_rule_handle_model = require("rule-func.rule_handle_model")

--const define
local uri_len = 11
local rule_pre_index = 1
local rule_post_index = 11

local function creat_respone_message(result, descrip)
	local payload={}
	payload["Result"] = result
	payload["Descrip"] = descrip
	local message={}
	message["Payload"] = payload
	
	return cjson.encode(message)
end

local function message_pack(json_body,res)
	if json_body["MsgId"]~=nil then
		local return_json = cjson.decode(res)
		return_json["MsgId"] = json_body["MsgId"]
		local gw = g_sql_app.query_dev_info_tbl(0)
		if gw ~= nil and gw[1] ~=nil then
			return_json["GW"] = gw[1]["sn"]
		end
		return_json["Event"] = "ReqStsUpload"
		local res_str = cjson.encode(return_json)
		ngx.say(res_str)
	else
		ngx.say(res)
	end
	ngx.flush()
end

local function check_http_request(uri, request_method, request_body)
	--check method
	if request_method ~= "GET" and request_method ~= "POST" and request_method ~= "DELETE" and request_method ~= "PUT" then
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"method no support\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		ngx.flush()
		return false
	end

	--check uri
	local uri_sub = string.sub(uri,rule_pre_index,rule_post_index)
	if uri_sub ~= "/v0001/rule" then
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"uri prefix is error\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		ngx.flush()
		return false
	end

	if #uri ~= uri_len then
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"uri len is error\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		ngx.flush()
		return false
	end

	--check body
	local all_json = {}
	if pcall(cjson.decode, request_body) then
		-- 没有错误
		all_json = cjson.decode(request_body)
	else
		-- 错误
		ngx.log(ngx.ERR,"json format error")
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"json format error\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		ngx.flush()
		return false
	end

	if all_json["Token"] ~= nil then
		if type(all_json["Token"]) ~= "string" then
			ngx.log(ngx.ERR,"Token type err")
			local json_str = '{\n\"errcode\":400,\n \"msg\":\"Token type err\",\n\"payload\":{}\n}'
			ngx.say(json_str)
			ngx.flush()
			return false
		end
	end

	if all_json["MsgId"] ~= nil then
		if type(all_json["MsgId"]) ~= "string" then
			ngx.log(ngx.ERR,"MsgId type err")
			local json_str = '{\n\"errcode\":400,\n \"msg\":\"MsgId type err\",\n\"payload\":{}\n}'
			ngx.say(json_str)
			ngx.flush()
			return false
		end
	end
	local msg_id = all_json["MsgId"]

	if all_json["Payload"] == nil then
		ngx.log(ngx.ERR,"Rule body has no Payload")
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"Rule body has no Payload\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		ngx.flush()
		return false
	end

	local payload_json = all_json["Payload"]

	if type(payload_json["RuleType"]) ~= "string" then
		ngx.log(ngx.ERR,"RuleType type err")
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"RuleType type err\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		ngx.flush()
		return false
	end
	if payload_json["RuleType"] ~= "TimerRule" and payload_json["RuleType"] ~= "LinkageRule" and payload_json["RuleType"] ~= "DevopsRule" then
		ngx.log(ngx.ERR,"rule type error")
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"rule type error\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		ngx.flush()
		return false
	end
end

local function request_error_handle(err)
	ngx.log(ngx.ERR,"request_error_handle ERR: ", err)
end

local function request_cmd_handle()
	local uri = ngx.var.uri
	local request_method = ngx.var.request_method
	ngx.req.read_body()
	local request_body = ngx.req.get_body_data()

	local check = check_http_request(uri, request_method, request_body)
	if check == false then
		return
	end

	g_rule_handle_model.add_handle(request_method, request_body)
	
	local res = creat_respone_message(0, "Success")
	local json_body = cjson.decode(request_body)
	message_pack(json_body, res)
end

-------main function------------
local status = xpcall(request_cmd_handle, request_error_handle)

