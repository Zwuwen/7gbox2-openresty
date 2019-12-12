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
local g_cmd_sync = require("alone-func.cmd_sync")
local g_rule_timer = require("alone-func.rule_timer")
local g_report_event = require("alone-func.report_event")
local g_linkage_sync = require("alone-func.linkage_sync")
local g_cmd_micro = require("cmd-func.cmd_micro")

--function define
--POST 插入策略
local function create_rule(req_payload)
	local json_param = cjson.decode(req_payload)

	--插入
	for i,json_obj in ipairs(json_param["Rules"]) do
		--去除空格
		json_obj = g_rule_common.http_str_trim(json_obj)

		json_obj["RuleModule"] = g_rule_common.depend_rule_module(json_obj["DevType"])

		local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(json_obj["RuleUuid"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return false
		end
		if next(qres) == nil then
			ngx.log(ngx.INFO,"insert rule")
			local res,err = g_sql_app.insert_rule_tbl(json_obj)
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return false
			end
		else
			ngx.log(ngx.INFO,"rule exist")
			return false
		end

		--执行一次该方法的策略
		g_exec_rule.exec_rules_by_method(json_obj["DevType"], json_obj["DevId"], json_obj["ChannelId"], json_obj["Method"])

		--更新定时任务间隔
		g_rule_timer.refresh_rule_timer()
	end
	
	return true
end

--DELETE 删除策略
local function delete_rule(req_payload)
	local json_param = cjson.decode(req_payload)
	
	if json_param["Method"] == 'DelByRuleUuid' then
		for i,uuid in ipairs(json_param["Payload"]["Rules"]) do
			--删除策略
			local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(uuid)
			if qerr then
				ngx.log(ngx.ERR," ", qres,qerr)
				return false
			end
			if next(qres) == nil then
				ngx.log(ngx.INFO,"rule not exist")
			else
				ngx.log(ngx.INFO,"delete rule")
				local res,err = g_sql_app.delete_rule_tbl_by_uuid(uuid)
				if err then
					ngx.log(ngx.ERR," ", res,err)
					return false
				end

				--执行一次该方法的策略
				qres[1] = g_rule_common.db_str_trim(qres[1])
				g_exec_rule.exec_rules_by_method(qres[1]["dev_type"], qres[1]["dev_id"], qres[1]["dev_channel"], qres[1]["method"])

				--更新定时任务间隔
				g_rule_timer.refresh_rule_timer()
			end
		end
	elseif json_param["Method"] == 'DelByDevId' then
		local qres,qerr = g_sql_app.query_rule_tbl_by_devid(json_param["Payload"]["DevType"], json_param["Payload"]["DevId"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return false
		end
		if next(qres) == nil
		then
			ngx.log(ngx.INFO,"rule not exist")
		else
			ngx.log(ngx.INFO,"delete rule")
			local res,err = g_sql_app.delete_rule_tbl_by_dev_id(json_param["Payload"]["DevType"], json_param["Payload"]["DevId"])
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return false
			end
		end		

		--更新定时任务间隔
		g_rule_timer.refresh_rule_timer()
	else
		ngx.log(ngx.ERR,"delete rules, method error ")
		return false
	end
	
	return true
end

--PUT 更新策略
local function update_rule(req_payload)
	local json_param = cjson.decode(req_payload)

	for i,json_obj in ipairs(json_param["Rules"]) do
		--去除空格
		json_obj = g_rule_common.http_str_trim(json_obj)

		--更新策略
		if json_obj["RuleUuid"] == nil then
			ngx.log(ngx.ERR,"please input rule uuid")
			return false
		end
		json_obj["RuleModule"] = g_rule_common.depend_rule_module(json_obj["DevType"])

		local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(json_obj["RuleUuid"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return false
		end
		if next(qres) == nil
		then
			ngx.log(ngx.INFO,"has no rule")
			return false
		else
			ngx.log(ngx.INFO,"update rule")
			local res,err = g_sql_app.update_rule_tbl(json_obj["RuleUuid"],json_obj)
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return false
			end
		end

		--执行一次该方法的策略
		qres[1] = g_rule_common.db_str_trim(qres[1])
		g_exec_rule.exec_rules_by_method(qres[1]["dev_type"], qres[1]["dev_id"], qres[1]["dev_channel"], qres[1]["method"])

		--更新定时任务间隔
		g_rule_timer.refresh_rule_timer()
	end
	
	return true
end

--转换数据库字段名
local function change_attr_name(src_obj)
	local dst_obj = {}

	dst_obj["RuleUuid"]  = src_obj["rule_uuid"]
	dst_obj["DevType"]   = src_obj["dev_type"]
	dst_obj["DevId"]	 = src_obj["dev_id"]
	dst_obj["ChannelId"] = src_obj["dev_channel"]
	dst_obj["Method"]    = src_obj["method"]
	dst_obj["Priority"]  = src_obj["priority"]

	dst_obj["RuleParam"] = src_obj["rule_param"]
	dst_obj["StartTime"] = src_obj["start_time"]
	dst_obj["EndTime"]   = src_obj["end_time"]
	dst_obj["StartDate"] = src_obj["start_date"]
	dst_obj["EndDate"]   = src_obj["end_date"]
	dst_obj["Running"]   = src_obj["running"]

	dst_obj["RuleParam"] = cjson.decode(dst_obj["RuleParam"])
	
	return dst_obj
end

--GET 查询策略
--输入：string req_payload
--输出：table f_rule_array
local function select_rule(req_payload)
	local f_rule_array = {}
	local f_json_param = {}

	if req_payload == nil then
		--body为空：获取全部策略
		local all_table,err = g_sql_app.query_rule_tbl_all()
		
		if err then
			ngx.log(ngx.ERR," ", err)
			return false, {}
		end
		if next(all_table) == nil then
			--数据库为空
		else
			for i,w in ipairs(all_table) do
				f_rule_array[i] = change_attr_name(w)
			end
		end
	else
		f_json_param = cjson.decode(req_payload)
	end

	if f_json_param["Rules"] ~= nil then
		for i,uuid in ipairs(f_json_param["Rules"]) do
			local uuid_table,err = g_sql_app.query_rule_tbl_by_uuid(uuid)

			if err then
				ngx.log(ngx.ERR," ", err)
				return false, {}
			end
			if next(uuid_table) == nil then
				--无所选策略
			else
				local uuid_obj = {}
				for j,w in ipairs(uuid_table) do
					uuid_obj = w
				end
				f_rule_array[i] = change_attr_name(uuid_obj)
			end
		end
	elseif f_json_param["Devices"] ~= nil then
		for i,dev in ipairs(f_json_param["Devices"]) do
			local dev_table,err = g_sql_app.query_rule_tbl_by_devid(dev["DevType"], dev["DevId"])

			if err then
				ngx.log(ngx.ERR," ", err)
				return false, {}
			end
			if next(dev_table) == nil then
				--无所选策略
			else
				local dev_obj = {}
				for j,w in ipairs(dev_table) do
					dev_obj[j] = change_attr_name(w)
				end
				f_rule_array[i] = dev_obj
			end	
		end
	end

	ngx.log(ngx.ERR,"query payload: ", cjson.encode(f_rule_array))
	return true,f_rule_array
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
	
	--f_table["errcode"] = errcode
	--f_table["msg"] = msg
	f_table["Rules"] = data_table
	
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

local check_json = cjson.decode(request_body)

local msg_id = check_json["MsgId"]
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
		result,data_table = select_rule(request_body)
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
		result = create_rule(request_body)
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
		result = update_rule(request_body)
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
		result = delete_rule(request_body)
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