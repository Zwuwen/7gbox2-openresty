--alone function
--restful parsing parameters
--version/rule/rule_uuid

--const define
local uri_len = 11
local rule_pre_index = 1
local rule_post_index = 11

--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_exec_rule = require("alone-func.exec_rule")
--local g_cmd_sync = require("alone-func.cmd_sync")
local g_rule_timer = require("alone-func.rule_timer")
local g_report_event = require("alone-func.rule_report_event")
--local g_linkage_sync = require("alone-func.linkage_sync")
local g_cmd_micro = require("cmd-func.cmd_micro")

--function define
local function is_key_exist(key)
	if key == "RuleUuid" then
	elseif key == "DevType" then
	elseif key == "DevId" then
	elseif key == "DevChannel" then
	elseif key == "Method" then
	elseif key == "Priority" then
	elseif key == "RuleParam" then
	elseif key == "StartTime" then
	elseif key == "EndTime" then
	elseif key == "StartDate" then
	elseif key == "EndDate" then
	else
		return false
	end

	return true
end

local function check_rule_input(table)
	if table["RuleUuid"] ~= nil then
		if type(table["RuleUuid"]) ~= "string" then
			ngx.log(ngx.ERR,"RuleUuid type err")
			return "RuleUuid type err", false
		end
	end

	if table["DevType"] ~= nil then
		if type(table["DevType"]) ~= "string" then
			ngx.log(ngx.ERR,"DevType type err")
			return "DevType type err", false
		end
	end

	if table["DevId"] ~= nil then
		if type(table["DevId"]) ~= "number" then
			ngx.log(ngx.ERR,"DevId type err")
			return "DevId type err", false
		end

		if table["DevId"] <= 0 then
			return "DevId <= 0", false
		end
	end

	if table["DevChannel"] ~= nil then
		if type(table["DevChannel"]) ~= "number" then
			ngx.log(ngx.ERR,"DevChannel type err")
			return "DevChannel type err", false
		end

		if table["DevChannel"] <= 0 then
			return "DevChannel <= 0", false
		end
	end

	if table["Method"] ~= nil then
		if type(table["Method"]) ~= "string" then
			ngx.log(ngx.ERR,"Method type err")
			return "Method type err", false
		end
	end

	if table["Priority"] ~= nil then
		if type(table["Priority"]) ~= "number" then
			ngx.log(ngx.ERR,"Priority type err")
			return "Priority type err", false
		end

		if table["Priority"] <= 0 then
			return "Priority <= 0", false
		end
	end

	if table["RuleParam"] ~= nil then
		if type(table["RuleParam"]) ~= "table" then
			ngx.log(ngx.ERR,"RuleParam type err")
			return "RuleParam type err", false
		end
	end

	if table["StartTime"] ~= nil then
		if type(table["StartTime"]) ~= "string" then
			ngx.log(ngx.ERR,"StartTime type err")
			return "StartTime type err", false
		end
	end

	if table["EndTime"] ~= nil then
		if type(table["EndTime"]) ~= "string" then
			ngx.log(ngx.ERR,"EndTime type err")
			return "EndTime type err", false
		end
	end

	if table["StartDate"] ~= nil then
		if type(table["StartDate"]) ~= "string" then
			ngx.log(ngx.ERR,"StartDate type err")
			return "StartDate type err", false
		end
	end

	if table["EndDate"] ~= nil then
		if type(table["EndDate"]) ~= "string" then
			ngx.log(ngx.ERR,"EndDate type err")
			return "EndDate type err", false
		end
	end

	return "", true
end

--POST 插入策略
local function create_rule(req_payload)
	local json_param = cjson.decode(req_payload)

	--插入
	for i,json_obj in ipairs(json_param["Rules"]) do
		local res,err = check_rule_input(json_obj)
		if err == false then
			ngx.log(ngx.ERR," ", res)
			return res, false
		end

		if (json_obj["Priority"] < g_rule_common.time_priority_h or 
		   	json_obj["Priority"] > g_rule_common.time_priority_l)
		then
			ngx.log(ngx.ERR,"time rule priority is 8~13")
			return "time rule priority should be 8~13", false
		end

		--去除空格
		json_obj = g_rule_common.http_str_trim(json_obj)

		local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(json_obj["RuleUuid"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return qerr, false
		end
		if next(qres) == nil then
			ngx.log(ngx.INFO,"insert rule: ", json_obj["RuleUuid"])
			local res,err = g_sql_app.insert_rule_tbl(json_obj)
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return err, false
			end
		else
			ngx.log(ngx.INFO,"rule exist")
			return "rule exist", false
		end

		--执行一次该方法的策略
		g_exec_rule.exec_rules_by_method(json_obj["DevType"], json_obj["DevId"], json_obj["DevChannel"], json_obj["Method"])

		--更新定时任务间隔
		g_rule_timer.refresh_rule_timer()
	end
	
	return "", true
end

--DELETE 删除策略
local function delete_rule(req_payload)
	local json_param = cjson.decode(req_payload)

	local method = json_param["Method"]
	local payload = json_param["Payload"]

	if (method == nil) then
		ngx.log(ngx.ERR,"Method key err")
		return "Method key err", false
	end
	if (payload == nil) then
		ngx.log(ngx.ERR,"Payload key err")
		return "Payload key err", false
	end

	if method == 'DelByRuleUuid' then
		if (payload["Rules"] == nil) then
			ngx.log(ngx.ERR,"Rules key err")
			return "Rules key err", false
		end
		for i,uuid in ipairs(payload["Rules"]) do
			if type(uuid) ~= "string" then
				ngx.log(ngx.ERR,"RuleUuid type err")
				return "RuleUuid type err", false
			end

			--删除策略
			local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(uuid)
			if qerr then
				ngx.log(ngx.ERR," ", qres,qerr)
				return qerr, false
			end
			if next(qres) == nil then
				ngx.log(ngx.INFO,"rule not exist")
			else
				ngx.log(ngx.INFO,"delete rule: ", uuid)
				local res,err = g_sql_app.delete_rule_tbl_by_uuid(uuid)
				if err then
					ngx.log(ngx.ERR," ", res,err)
					return err, false
				end

				--执行一次该方法的策略
				qres[1] = g_rule_common.db_str_trim(qres[1])
				g_exec_rule.exec_rules_by_method(qres[1]["dev_type"], qres[1]["dev_id"], qres[1]["dev_channel"], qres[1]["method"])

				--更新定时任务间隔
				g_rule_timer.refresh_rule_timer()
			end
		end
	elseif method == 'DelByDevId' then
		if (payload["DevType"] == nil) then
			ngx.log(ngx.ERR,"DevType key err")
			return "DevType key err", false
		end
		if (payload["DevId"] == nil) then
			ngx.log(ngx.ERR,"DevId key err")
			return "DevId key err", false
		end

		local res,err = check_rule_input(payload)
		if err == false then
			ngx.log(ngx.ERR," ", res)
			return res, false
		end

		local qres,qerr = g_sql_app.query_rule_tbl_by_devid(payload["DevType"], payload["DevId"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return qerr, false
		end
		if next(qres) == nil
		then
			ngx.log(ngx.INFO,"rule not exist")
		else
			ngx.log(ngx.INFO,"delete rule: ", payload["DevType"]..", "..payload["DevId"])
			local res,err = g_sql_app.delete_rule_tbl_by_dev_id(payload["DevType"], payload["DevId"])
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return err, false
			end
		end		

		--更新定时任务间隔
		g_rule_timer.refresh_rule_timer()
	else
		ngx.log(ngx.ERR,"delete rules, method error ")
		return "delete rules, method error", false
	end
	
	return "", true
end

--PUT 更新策略
local function update_rule(req_payload)
	local json_param = cjson.decode(req_payload)

	for i,json_obj in ipairs(json_param["Rules"]) do
		if json_obj["RuleUuid"] == nil then
			ngx.log(ngx.ERR,"please input rule uuid")
			return "please input rule uuid", false
		end

		for key,value in pairs(json_obj) do
			local rt = is_key_exist(key)
			if rt == false then
				ngx.log(ngx.ERR,key.." error")
				return key.." error", false
			end
		end

		local res,err = check_rule_input(json_obj)
		if err == false then
			ngx.log(ngx.ERR," ", res)
			return res, false
		end

		--去除空格
		json_obj = g_rule_common.http_str_trim(json_obj)

		--更新策略
		local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(json_obj["RuleUuid"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return qerr, false
		end
		if next(qres) == nil
		then
			ngx.log(ngx.INFO,"rule not exist")
			return "rule not exist", false
		else
			ngx.log(ngx.INFO,"update rule: ", json_obj["RuleUuid"])
			local res,err = g_sql_app.update_rule_tbl(json_obj["RuleUuid"],json_obj)
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return err, false
			end
		end

		--执行一次该方法的策略
		qres[1] = g_rule_common.db_str_trim(qres[1])
		g_exec_rule.exec_rules_by_method(qres[1]["dev_type"], qres[1]["dev_id"], qres[1]["dev_channel"], qres[1]["method"])

		--更新定时任务间隔
		g_rule_timer.refresh_rule_timer()
	end
	
	return "", true
end

--GET 查询策略
--输入：string req_payload
--输出：table f_rule_array
local function select_rule(req_payload)
	local f_rule_array = {}
	local f_json_param = {}

	f_json_param = cjson.decode(req_payload)

	if f_json_param["Rules"] ~= nil then
		--uuid
		for i,uuid in ipairs(f_json_param["Rules"]) do
			if type(uuid) ~= "string" then
				ngx.log(ngx.ERR,"RuleUuid type err")
				return "RuleUuid type err", false
			end

			local uuid_table,err = g_sql_app.query_rule_tbl_by_uuid(uuid)

			if err then
				ngx.log(ngx.ERR," ", err)
				return err, false
			end
			if next(uuid_table) == nil then
				--无所选策略
			else
				local uuid_obj = {}
				for j,w in ipairs(uuid_table) do
					uuid_obj = w
				end
				f_rule_array[i] = g_rule_common.db_attr_to_display(uuid_obj)
			end
		end
	elseif f_json_param["Devices"] ~= nil then
		--dev
		for i,dev in ipairs(f_json_param["Devices"]) do
			if (dev["DevType"] == nil) then
				ngx.log(ngx.ERR,"DevType key err")
				return "DevType key err", false
			end
			if (dev["DevId"] == nil) then
				ngx.log(ngx.ERR,"DevId key err")
				return "DevId key err", false
			end

			local res,err = check_rule_input(dev)
			if err == false then
				ngx.log(ngx.ERR," ", res)
				return res, false
			end

			local dev_table,err = g_sql_app.query_rule_tbl_by_devid(dev["DevType"], dev["DevId"])

			if err then
				ngx.log(ngx.ERR," ", err)
				return err, false
			end
			if next(dev_table) == nil then
				--无所选策略
			else
				local dev_obj = {}
				for j,w in ipairs(dev_table) do
					dev_obj[j] = g_rule_common.db_attr_to_display(w)
				end
				f_rule_array[i] = dev_obj
			end	
		end
	else
		f_json_param["RuleType"] = nil	--删除RuleType
		for key, value in pairs(f_json_param) do
			--ngx.log(ngx.INFO,key..": "..value)
		end

		if next(f_json_param) == nil then
			--body为空：获取全部策略
			ngx.log(ngx.INFO,"query all rule")
			local all_table,err = g_sql_app.query_rule_tbl_all()
			if err then
				ngx.log(ngx.ERR," ", err)
				return err, false
			end
			if next(all_table) == nil then
				--数据库为空
			else
				for i,w in ipairs(all_table) do
					f_rule_array[i] = g_rule_common.db_attr_to_display(w)
				end
			end
		else
			ngx.log(ngx.ERR,"query method err")
			return "query method err", false
		end
	end

	ngx.log(ngx.ERR,"query payload: ", cjson.encode(f_rule_array))
	return f_rule_array, true
end

--生成请求的响应数据
local function encode_insert_response(errcode, msg, data_table)
	local f_table = {}
	local f_str = ''
	
	local payload = {}
	payload["Result"] = errcode
	payload["Descrip"] = msg
	payload["Out"] = data_table
	f_table["Payload"] = payload
	
	f_str = cjson.encode(f_table)
	--ngx.log(ngx.ERR," ", f_str)
	return f_str
end

local function encode_update_response(errcode, msg, data_table)
	local f_table = {}
	local f_str = ''
	
	local payload = {}
	payload["Result"] = errcode
	payload["Descrip"] = msg
	payload["Out"] = data_table
	f_table["Payload"] = payload
	
	f_str = cjson.encode(f_table)
	--ngx.log(ngx.ERR," ", f_str)
	return f_str
end

local function encode_delete_response(errcode, msg, data_table)
	local f_table = {}
	local f_str = ''
	
	local payload = {}
	payload["Result"] = errcode
	payload["Descrip"] = msg
	payload["Out"] = data_table
	f_table["Payload"] = payload
	
	f_str = cjson.encode(f_table)
	--ngx.log(ngx.ERR," ", f_str)
	return f_str
end

local function encode_select_response(errcode, msg, data_table)
	local f_table = {}
	local f_str = ''
	
	if errcode == 0 then
		--查询成功
		f_table["Rules"] = data_table
	else
		--查询失败
		local payload = {}
		payload["Result"] = errcode
		payload["Descrip"] = msg
		payload["Out"] = data_table
		f_table["Payload"] = payload
	end
	
	f_str = cjson.encode(f_table)
	--ngx.log(ngx.ERR," ", f_str)
	return f_str
end

--------------------------------main function----------------------------
--check uri
local request_method = ngx.var.request_method
if request_method ~= "GET" and request_method ~= "POST" and request_method ~= "DELETE" and request_method ~= "PUT" then
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"method no support\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	return
end

local uri = ngx.var.uri
local uri_sub = string.sub(uri,rule_pre_index,rule_post_index)
if uri_sub ~= "/v0001/rule" then
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"uri prefix is error\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	return
end

if #uri ~= uri_len then
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"uri len is error\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	return
end

--check body
ngx.req.read_body()
local request_body = ngx.req.get_body_data()

local check_json = {}
if pcall(cjson.decode, request_body) then
	-- 没有错误
	check_json = cjson.decode(request_body)
else
	-- 错误
	ngx.log(ngx.ERR,"json format error")
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"json format error\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	return
end

if check_json["Token"] ~= nil then
	if type(check_json["Token"]) ~= "string" then
		ngx.log(ngx.ERR,"Token type err")
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"Token type err\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		return
	end
end

if check_json["MsgId"] ~= nil then
	if type(check_json["MsgId"]) ~= "string" then
		ngx.log(ngx.ERR,"MsgId type err")
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"MsgId type err\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		return
	end
end
local msg_id = check_json["MsgId"]

if type(check_json["RuleType"]) ~= "string" then
	ngx.log(ngx.ERR,"RuleType type err")
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"RuleType type err\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	return
end
if check_json["RuleType"] ~= "TimerRule" and check_json["RuleType"] ~= "LinkageRule" then
	ngx.log(ngx.ERR,"rule type error")
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"rule type error\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	return
end
local linkage_ser = "RuleEngine"

--exec
if request_method == "GET" then
	local result = false
	local data_table = {}
	local data_str = ""
	if check_json["RuleType"] == "TimerRule" then
		data_table, result = select_rule(request_body)
	elseif check_json["RuleType"] == "LinkageRule" then
		data_str, result = g_cmd_micro.micro_get(linkage_ser,request_body)
		ngx.say(data_str)
		return
	end
	
	if result == false then
		local json_str = encode_select_response(1, 'Failure', data_table)
		ngx.say(json_str)
	else
		local json_str = encode_select_response(0, 'Success', data_table)
		ngx.say(json_str)
	end
elseif request_method == "POST" then
	local result = false
	local data_table = {}
	local data_str = ""
	if check_json["RuleType"] == "TimerRule" then
		data_table, result = create_rule(request_body)
	elseif check_json["RuleType"] == "LinkageRule" then
		data_str, result = g_cmd_micro.micro_post(linkage_ser,request_body)
		ngx.say(data_str)
		return
	end

	if result == false then
		local json_str = encode_insert_response(1, 'Failure', data_table)
		ngx.say(json_str)
		g_report_event.report_status(msg_id, 1, 'Failure', data_table)
	else
		local json_str = encode_insert_response(0, 'Success', data_table)
		ngx.say(json_str)
		g_report_event.report_status(msg_id, 0, 'Success', data_table)
	end
elseif request_method == "PUT" then
	local result = false
	local data_table = {}
	local data_str = ""
	if check_json["RuleType"] == "TimerRule" then
		data_table, result = update_rule(request_body)
	elseif check_json["RuleType"] == "LinkageRule" then
		data_str, result = g_cmd_micro.micro_put(linkage_ser,request_body)
		ngx.say(data_str)
		return
	end

	if result == false then
		local json_str = encode_update_response(1, 'Failure', data_table)
		ngx.say(json_str)
		g_report_event.report_status(msg_id, 1, 'Failure', data_table)
	else
		local json_str = encode_update_response(0, 'Success', data_table)
		ngx.say(json_str)
		g_report_event.report_status(msg_id, 0, 'Success', data_table)
	end
elseif request_method == "DELETE" then
	local result = false
	local data_table = {}
	local data_str = ""
	if check_json["RuleType"] == "TimerRule" then
		data_table, result = delete_rule(request_body)
	elseif check_json["RuleType"] == "LinkageRule" then
		data_str, result = g_cmd_micro.micro_delete(linkage_ser,request_body)
		ngx.say(data_str)
		return
	end

	if result == false then
		local json_str = encode_delete_response(1, 'Failure', data_table)
		ngx.say(json_str)
		g_report_event.report_status(msg_id, 1, 'Failure', data_table)
	else
		local json_str = encode_delete_response(0, 'Success', data_table)
		ngx.say(json_str)
		g_report_event.report_status(msg_id, 0, 'Success', data_table)
	end
end
