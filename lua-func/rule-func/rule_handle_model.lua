local m_rule_handle = {}

local g_rule_handle_body_table = {}
local g_is_rule_handle_timer_running = false
local g_rule_handle_body_table_locker = false
local dev_set = {}

--load module
local g_rule_common = require("rule-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_exec_rule = require("rule-func.exec_rule")
local g_dev_dft = require("rule-func.dev_default")
--local g_cmd_sync = require("rule-func.cmd_sync")
local g_rule_timer = require("rule-func.rule_timer")
local g_report_event = require("rule-func.rule_report_event")
--local g_linkage_sync = require("rule-func.linkage_sync")
local g_cmd_micro = require("cmd-func.cmd_micro")
local report_event  = require("event-func.event_report")
--function define
---------------------------------------------------------------------------------
--输入检查
---------------------------------------------------------------------------------
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
	elseif key == "Actions" then
	else
		return false
	end

	return true
end

--检测单个属性
local function check_rule_input(table)
	if table["RuleUuid"] ~= nil then
		if type(table["RuleUuid"]) ~= "string" then
			ngx.log(ngx.ERR,"RuleUuid type err")
			return "RuleUuid type err", 2
		end
	end

	if table["DevType"] ~= nil then
		if type(table["DevType"]) ~= "string" then
			ngx.log(ngx.ERR,"DevType type err")
			return "DevType type err", 2
		end
	end

	if table["DevId"] ~= nil then
		if type(table["DevId"]) ~= "number" then
			ngx.log(ngx.ERR,"DevId type err")
			return "DevId type err", 2
		end

		if table["DevId"] <= 0 then
			return "DevId <= 0", 2
		end
	end

	if table["DevChannel"] ~= nil then
		if type(table["DevChannel"]) ~= "number" then
			ngx.log(ngx.ERR,"DevChannel type err")
			return "DevChannel type err", 2
		end

		if table["DevChannel"] <= 0 then
			return "DevChannel <= 0", 2
		end
	end

	if table["Priority"] ~= nil then
		if type(table["Priority"]) ~= "number" then
			ngx.log(ngx.ERR,"Priority type err")
			return "Priority type err", 2
		end

		if table["Priority"] <= 0 then
			return "Priority <= 0", 2
		end
	end

	if table["Actions"] ~= nil then
		if type(table["Actions"]) ~= "table" then
			ngx.log(ngx.ERR,"Actions type err")
			return "Actions type err", 2
		end
	end

	if table["Method"] ~= nil then
		if type(table["Method"]) ~= "string" then
			ngx.log(ngx.ERR,"Method type err")
			return "Method type err", 2
		end
	end

	if table["RuleParam"] ~= nil then
		if type(table["RuleParam"]) ~= "table" then
			ngx.log(ngx.ERR,"RuleParam type err")
			return "RuleParam type err", 2
		end
	end

	if table["StartTime"] ~= nil then
		if type(table["StartTime"]) ~= "string" then
			ngx.log(ngx.ERR,"StartTime type err")
			return "StartTime type err", 2
		end
	end

	if table["EndTime"] ~= nil then
		if type(table["EndTime"]) ~= "string" then
			ngx.log(ngx.ERR,"EndTime type err")
			return "EndTime type err", 2
		end
	end

	if table["StartDate"] ~= nil then
		if type(table["StartDate"]) ~= "string" then
			ngx.log(ngx.ERR,"StartDate type err")
			return "StartDate type err", 2
		end
	end

	if table["EndDate"] ~= nil then
		if type(table["EndDate"]) ~= "string" then
			ngx.log(ngx.ERR,"EndDate type err")
			return "EndDate type err", 2
		end
	end

	return "", 0
end

--将有策略要执行的设备加入集合
local function add_to_dev_set(dev_type, dev_id, channel)
	local device = {}
	device["DevType"] = dev_type
	device["DevId"] = dev_id
	device["DevChannel"] = channel

	for i,saved_dev in ipairs(dev_set) do
		if (saved_dev["DevType"] == device["DevType"]) and
			(saved_dev["DevId"] == device["DevId"]) and
			(saved_dev["DevChannel"] == device["DevChannel"])
		then
			--设备已经存在，不插入
			return
		end
	end

	--dev_set是集合
    table.insert(dev_set, device)
end

--
local function exec_rule_in_devices()
	local rt_value_table = {}
	ngx.log(ngx.DEBUG,"exec dev_set: ", cjson.encode(dev_set))

	while next(dev_set) ~= nil do
		for i,device in ipairs(dev_set) do
			local has_other_dev = false
			if #dev_set > 1 then
				has_other_dev = true
			end
			local has_failed = g_exec_rule.exec_rules_by_devid(device["DevType"], device["DevId"], has_other_dev)
			table.insert(rt_value_table, has_failed)
			table.remove(dev_set, i)
			break
		end
	end

	local failed = g_rule_common.is_include(true, rt_value_table)

	--更新定时任务间隔
	g_rule_timer.refresh_rule_timer(failed)
end

---------------------------------------------------------------------------------
--method级增删改查方法
---------------------------------------------------------------------------------
--POST 插入策略
local function create_rule(req_payload)
	local json_param = cjson.decode(req_payload)

	--插入
	for i,json_obj in ipairs(json_param["Rules"]) do
		--去除空格
		json_obj = g_rule_common.http_str_trim(json_obj)

		local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(json_obj["RuleUuid"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return qerr, 1
		end
		if next(qres) == nil then
			ngx.log(ngx.INFO,"insert rule: ", json_obj["RuleUuid"])
			local res,err = g_sql_app.insert_rule_tbl(json_obj)
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return err, 1
			end
		else
			ngx.log(ngx.INFO,"rule exist")
			return "rule exist", 2
		end

		add_to_dev_set(json_obj["DevType"], json_obj["DevId"], json_obj["DevChannel"])
	end
	
	return "", 0
end

--DELETE 删除策略
local function delete_rule(req_payload)
	local json_param = cjson.decode(req_payload)

	local method = json_param["Method"]
	local payload = json_param

	if method == 'DelByRuleUuid' then
		for i,uuid in ipairs(payload["Rules"]) do
			--删除策略
			local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(uuid)
			if qerr then
				ngx.log(ngx.ERR," ", qres,qerr)
				return qerr, 1
			end
			if next(qres) == nil then
				ngx.log(ngx.INFO,"rule not exist")
				return "rule not exist", 2
			else
				ngx.log(ngx.INFO,"delete rule: ", uuid)
				local res,err = g_sql_app.delete_rule_tbl_by_uuid(uuid)
				if err then
					ngx.log(ngx.ERR," ", res,err)
					return err, 1
				end

				--上报原有策略执行结束
				if qres[1]["running"] == 1 then
					ngx.log(ngx.INFO,"report "..qres[1]["dev_type"].."-"..qres[1]["dev_id"].."-"..qres[1]["dev_channel"].."-"..qres[1]["rule_uuid"].." end")
					g_report_event.report_rule_exec_status(qres[1], "End", 0, nil, nil)

					add_to_dev_set(qres[1]["dev_type"], qres[1]["dev_id"], qres[1]["dev_channel"])
				end				
			end
		end
	elseif method == 'DelByDevId' then
		local qres,qerr = g_sql_app.query_rule_tbl_by_devid(payload["DevType"], payload["DevId"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return qerr, 1
		end
		if next(qres) == nil
		then
			ngx.log(ngx.INFO,"rule not exist")
			return "rule not exist", 2
		else
			ngx.log(ngx.INFO,"delete rule: ", payload["DevType"]..", "..payload["DevId"])
			local res,err = g_sql_app.delete_rule_tbl_by_dev_id(payload["DevType"], payload["DevId"])
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return err, 1
			end
		end		

		--上报原有策略执行结束
		for i,rule in ipairs(qres) do
			if rule["running"] == 1 then
				--有正在运行策略，上报策略结束
				ngx.log(ngx.INFO,"report "..rule["dev_type"].."-"..rule["dev_id"].."-"..rule["dev_channel"].."-"..rule["rule_uuid"].." end")
				g_report_event.report_rule_exec_status(rule, "End", 0, nil, nil)
			end
		end		

		add_to_dev_set(payload["DevType"], payload["DevId"], 0)
	else
		ngx.log(ngx.ERR,"delete rules, method error ")
		return "delete rules, method error", 2
	end
	
	return "", 0
end

--PUT 更新策略
local function update_rule(req_payload)
	local json_param = cjson.decode(req_payload)

	for i,json_obj in ipairs(json_param["Rules"]) do
		--去除空格
		json_obj = g_rule_common.http_str_trim(json_obj)

		--更新策略
		local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(json_obj["RuleUuid"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return qerr, 1
		end
		if next(qres) == nil
		then
			ngx.log(ngx.INFO,"rule not exist")
			return "rule not exist", 2
		else
			ngx.log(ngx.INFO,"update rule: ", json_obj["RuleUuid"])
			local res,err = g_sql_app.update_rule_tbl(json_obj["RuleUuid"],json_obj)
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return err, 1
			end
		end

		add_to_dev_set(qres[1]["dev_type"], qres[1]["dev_id"], qres[1]["dev_channel"])
	end
	
	return "", 0
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
				return "RuleUuid type err", 2
			end

			local uuid_table,err = g_sql_app.query_rule_tbl_by_uuid(uuid)

			if err then
				ngx.log(ngx.ERR," ", err)
				return err, 1
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
				return "DevType key err", 2
			end
			if (dev["DevId"] == nil) then
				ngx.log(ngx.ERR,"DevId key err")
				return "DevId key err", 2
			end

			local res,err = check_rule_input(dev)
			if err ~= 0 then
				ngx.log(ngx.ERR," ", res)
				return res, 2
			end

			local dev_table,err = g_sql_app.query_rule_tbl_by_devid(dev["DevType"], dev["DevId"])

			if err then
				ngx.log(ngx.ERR," ", err)
				return err, 1
			end
			if next(dev_table) == nil then
				--无所选策略
			else
				local dev_obj = {}
				for j,w in ipairs(dev_table) do
					dev_obj[j] = g_rule_common.db_attr_to_display(w)
				end
				table.insert(f_rule_array, dev_obj)
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
				return err, 1
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
			return "query method err", 2
		end
	end

	--ngx.log(ngx.ERR,"query payload: ", cjson.encode(f_rule_array))
	return f_rule_array, 0
end

---------------------------------------------------------------------------------
--增删改查方法封装
---------------------------------------------------------------------------------
--检测并取消正在下发的策略
local function check_device_rule_idle_status(dev_type, dev_id, channel)
	local wait_time = 0
	while wait_time < 30 do
		--策略下发
		local exec_idle = g_exec_rule.get_device_rule_idle_status(dev_type, dev_id, channel)
		if exec_idle == false then
			g_exec_rule.stop_device_rule_exec(dev_type, dev_id, channel)
		end
		--检查默认状态设置
		local dft_idle = g_dev_dft.get_device_dft_idle_status(dev_type, dev_id, channel)
		if dft_idle == false then
			g_dev_dft.stop_device_dft_exec(dev_type, dev_id, channel)
		end

		if (exec_idle == true) and
			(dft_idle == true)
		then
			return "", 0
		end
		wait_time = wait_time + 1
		ngx.sleep(0.1)
	end

	if wait_time >= 30 then
		--超时
		ngx.log(ngx.ERR,"cancel rule timeout")
		return "device busy", 13
	end
end

--插入策略组
local function create_rule_group(all_json)
	local all_table = cjson.decode(all_json)
	local payload = all_table["Payload"]

	--
	if (payload["Rules"] == nil) then
		ngx.log(ngx.ERR,"Rules key err")
		return "Rules key err", 2
	end
	for i,rule_obj in ipairs(payload["Rules"]) do
		--检查json第一层
		if (rule_obj["RuleUuid"] == nil) or
		(rule_obj["DevType"] == nil) or
		(rule_obj["DevId"] == nil) or
		(rule_obj["DevChannel"] == nil) or
		(rule_obj["Priority"] == nil) or
		(rule_obj["StartTime"] == nil) or
		(rule_obj["EndTime"] == nil) or
		(rule_obj["StartDate"] == nil) or
		(rule_obj["EndDate"] == nil) or
		(rule_obj["Actions"] == nil) 
		then
			ngx.log(ngx.ERR,"input param incomplete")
			return "input param incomplete", 2
		end

		local res,err = check_rule_input(rule_obj)
		if err ~= 0 then
			ngx.log(ngx.ERR," ", res)
			return res, 2
		end

		if (rule_obj["Priority"] < g_rule_common.time_priority_h or 
			rule_obj["Priority"] > g_rule_common.time_priority_l)
		then
			ngx.log(ngx.ERR,"time rule priority is 8~13")
			return "time rule priority should be 8~13", 2
		end

		--检查json第二层
		local rule_group = {}
		local tmp_rule_group = {}
		if rule_obj["DevType"] == "Lamp" then
			rule_group = {"SetOnOff", "SetBrightness"}
		elseif rule_obj["DevType"] == "InfoScreen" then
			rule_group = {"SetOnOff", "PlayProgram", "SetBrightness", "SetVolume"}
		elseif rule_obj["DevType"] == "IPC-Onvif" then
			rule_group = {"GotoPreset"}
		elseif rule_obj["DevType"] == "Speaker" then
			rule_group = {"PlayProgram"}
		else
			ngx.log(ngx.ERR,"DevType error")
			return "DevType error", 2
		end
		ngx.log(ngx.DEBUG,"rule group require method: ", cjson.encode(rule_group))
				
		for i,action in ipairs(rule_obj["Actions"]) do
			if (action["Method"] == nil) then
				ngx.log(ngx.ERR,"Method key err")
				return "Method key err", 2
			end
			if (action["RuleParam"] == nil) then
				ngx.log(ngx.ERR,"RuleParam key err")
				return "RuleParam key err", 2
			end
			local res,err = check_rule_input(action)
			if err ~= 0 then
				ngx.log(ngx.ERR," ", res)
				return res, 2
			end

			table.insert(tmp_rule_group, action["Method"])
		end
		ngx.log(ngx.DEBUG,"input rule group method: ", cjson.encode(tmp_rule_group))

		for i,method in ipairs(rule_group) do
			local err = g_rule_common.is_include(method, tmp_rule_group)
			if err == false then
				ngx.log(ngx.ERR,"rule group method not complete")
				return "rule group method not complete", 2
			end

			for i,tmp_method in ipairs(tmp_rule_group) do
				if method == tmp_method then
					table.remove(tmp_rule_group, i)
				end
			end
		end
		if next(tmp_rule_group) ~= nil then
			ngx.log(ngx.ERR,"rule group method too much")
			return "rule group method too much", 2
		end

		--检查该设备是否正在执行策略
		local desp, status = check_device_rule_idle_status(rule_obj["DevType"], rule_obj["DevId"], rule_obj["DevChannel"])
		if status ~= 0 then
			return desp, status
		end
	end

	--插入策略
	local tmp_rule_json = cjson.encode(payload)
	ngx.log(ngx.DEBUG,"insert sub json: ", tmp_rule_json)
	local res,err = create_rule(tmp_rule_json)
	if err ~= 0 then
		ngx.log(ngx.ERR,"insert rule fail")
		return res, err
	end

	--执行策略
	exec_rule_in_devices()

	return "", 0
end

--删除策略组
local function delete_rule_group(all_json)
	local all_table = cjson.decode(all_json)
	if (all_table["Payload"] == nil) then
		ngx.log(ngx.ERR,"Payload key err")
		return "Payload key err", 2
	end

	local payload = all_table["Payload"]


	if (payload["Method"] == nil) then
		ngx.log(ngx.ERR,"Method key err")
		return "Method key err", 2
	end
	local method = payload["Method"]

	if method == 'DelByRuleUuid' then
		if (payload["Rules"] == nil) then
			ngx.log(ngx.ERR,"Rules key err")
			return "Rules key err", 2
		else
			if type(payload["Rules"]) ~= "table" then
				ngx.log(ngx.ERR,"Rules type err")
				return "Rules type err", 2
			end
		end
		for i,uuid in ipairs(payload["Rules"]) do
			if type(uuid) ~= "string" then
				ngx.log(ngx.ERR,"RuleUuid type err")
				return "RuleUuid type err", 2
			end

			--删除策略
			local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(uuid)
			if qerr then
				ngx.log(ngx.ERR," ", qres,qerr)
				return qerr, 1
			end
			if next(qres) == nil then
				ngx.log(ngx.INFO,"rule not exist")
				return "rule not exist", 2
			else
				--检查该设备是否正在执行策略
				local desp, status = check_device_rule_idle_status(qres[1]["dev_type"], qres[1]["dev_id"], qres[1]["dev_channel"])
				if status ~= 0 then
					return desp, status
				end
			end
		end
	elseif method == 'DelByDevId' then
		if (payload["DevType"] == nil) then
			ngx.log(ngx.ERR,"DevType key err")
			return "DevType key err", 2
		end
		if (payload["DevId"] == nil) then
			ngx.log(ngx.ERR,"DevId key err")
			return "DevId key err", 2
		end

		local res,err = check_rule_input(payload)
		if err ~= 0 then
			ngx.log(ngx.ERR," ", res)
			return res, 1
		end

		local qres,qerr = g_sql_app.query_rule_tbl_by_devid(payload["DevType"], payload["DevId"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return qerr, 1
		end
		if next(qres) == nil then
			ngx.log(ngx.INFO,"rule not exist")
			return "rule not exist", 2
		else
			--检查该设备是否正在执行策略
			local desp, status = check_device_rule_idle_status(payload["DevType"], payload["DevId"], 0)
			if status ~= 0 then
				return desp, status
			end
		end
	else
		ngx.log(ngx.ERR,"delete rules, method error ")
		return "delete rules, method error", 2
	end
	

	local sub_json = cjson.encode(payload)
	ngx.log(ngx.INFO,"delete rule sub json: ", sub_json)
	local res, err = delete_rule(sub_json)
	if err ~= 0 then
		ngx.log(ngx.ERR,"delete rule fail")
		return res, err
	end

	--执行策略
	exec_rule_in_devices()

	return "", 0
end

--更新策略组
local function update_rule_group(all_json)
	local all_table = cjson.decode(all_json)
	local payload = all_table["Payload"]

	--
	if (payload["Rules"] == nil) then
		ngx.log(ngx.ERR,"Rules key err")
		return "Rules key err", 2
	end
	for i,rule_obj in ipairs(payload["Rules"]) do
		--检查json第一层
		if rule_obj["RuleUuid"] == nil then
			ngx.log(ngx.ERR,"please input rule uuid")
			return "please input rule uuid", 2
		end

		if rule_obj["Priority"] ~= nil then
			if (rule_obj["Priority"] < g_rule_common.time_priority_h or 
				rule_obj["Priority"] > g_rule_common.time_priority_l)
			then
				ngx.log(ngx.ERR,"time rule priority is 8~13")
				return "time rule priority should be 8~13", 2
			end
		end

		for key,value in pairs(rule_obj) do
			local rt = is_key_exist(key)
			if rt == false then
				ngx.log(ngx.ERR,key.." error")
				return key.." error", 2
			end
		end

		local res,err = check_rule_input(rule_obj)
		if err ~= 0 then
			ngx.log(ngx.ERR," ", res)
			return res, 2
		end
		
		--检查json第二层
		if (rule_obj["Actions"] ~= nil) and
		next(rule_obj["Actions"]) ~= nil
		then
			for i,action in ipairs(rule_obj["Actions"]) do
				if (action["Method"] == nil) then
					ngx.log(ngx.ERR,"Method key err")
					return "Method key err", 2
				end
				if (action["RuleParam"] == nil) then
					ngx.log(ngx.ERR,"RuleParam key err")
					return "RuleParam key err", 2
				end
				local res,err = check_rule_input(action)
				if err ~= 0 then
					ngx.log(ngx.ERR," ", res)
					return res, 2
				end
			end			
		end

		local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(rule_obj["RuleUuid"])
		if qerr then
			ngx.log(ngx.ERR," ", qres,qerr)
			return qerr, 1
		end
		if next(qres) == nil then
			ngx.log(ngx.INFO,"rule not exist")
			return "rule not exist", 2
		else
			--检查该设备是否正在执行策略
			local desp, status = check_device_rule_idle_status(qres[1]["dev_type"], qres[1]["dev_id"], qres[1]["dev_channel"])
			if status ~= 0 then
				return desp, status
			end
		end
	end

	--更新
	local res,err = update_rule(cjson.encode(payload))
	if err ~= 0 then
		ngx.log(ngx.ERR,"update rule fail")
		return res, err
	end

	--执行策略
	exec_rule_in_devices()

	return "", 0
end

--查询策略组
local function select_rule_group(all_json)
	local all_table = cjson.decode(all_json)
	local payload = all_table["Payload"]

	--查询时间策略
	local f_rule_array, err = select_rule(cjson.encode(payload))
	if err ~= 0 then
		ngx.log(ngx.ERR,"query time rule fail")
		return f_rule_array, err
	end

	ngx.log(ngx.ERR,"query payload: ", cjson.encode(f_rule_array))
	return f_rule_array, 0	
end

---------------------------------------------------------------------------------
--------------------------------main function------------------------------------
---------------------------------------------------------------------------------
local function http_method(request_method, request_body)
	local all_json = cjson.decode(request_body)
	local msg_id = all_json["MsgId"]
	local payload_json = all_json["Payload"]
	local linkage_ser = "RuleEngine"
	local devops_ser = "DevopsEngine"

	if request_method == "GET" then
		local result = false
		local data_table = {}
		local data_str = ""
		if payload_json["RuleType"] == "TimerRule" then
			data_table, result = select_rule_group(request_body)
			if result ~= 0 then
				g_report_event.report_status(msg_id, result, 'Failure', data_table)
			else
				g_report_event.report_status(msg_id, result, 'Success', data_table)
			end
			return
		elseif payload_json["RuleType"] == "LinkageRule" then
			data_str, result = g_cmd_micro.micro_get(linkage_ser,request_body)
			local return_json = cjson.decode(data_str)
			local gw = g_sql_app.query_dev_info_tbl(0)
			return_json["GW"] = gw[1]["sn"]
			local json_body = cjson.decode(request_body)
			return_json["MsgId"] = json_body["MsgId"]
			return_json["Event"] = "ResultUpload"
			report_event.method_respone(return_json)
			return
		elseif payload_json["RuleType"] == "DevopsRule" then
			data_str, result = g_cmd_micro.micro_get(devops_ser,request_body)
			local return_json = cjson.decode(data_str)
			local gw = g_sql_app.query_dev_info_tbl(0)
			return_json["GW"] = gw[1]["sn"]
			local json_body = cjson.decode(request_body)
			return_json["MsgId"] = json_body["MsgId"]
			return_json["Event"] = "ResultUpload"
			report_event.method_respone(return_json)
			return
		end
	elseif request_method == "POST" then
		local result = false
		local data_table = {}
		local data_str = ""
		if payload_json["RuleType"] == "TimerRule" then
			data_table, result = create_rule_group(request_body)
			if result ~= 0 then
				g_report_event.report_status(msg_id, result, 'Failure', data_table)
			else
				g_report_event.report_status(msg_id, result, 'Success', data_table)
			end
			return
		elseif payload_json["RuleType"] == "LinkageRule" then
			data_str, result = g_cmd_micro.micro_post(linkage_ser,request_body)
			if result == false then
				local return_json = cjson.decode(data_str)
				g_report_event.report_status(msg_id, return_json["Payload"]["Result"], return_json["Payload"]["Descrip"], {})
			end
			return
		elseif payload_json["RuleType"] == "DevopsRule" then
			data_str, result = g_cmd_micro.micro_post(devops_ser,request_body)
			if result == false then
				local return_json = cjson.decode(data_str)
				g_report_event.report_status(msg_id, return_json["Payload"]["Result"], return_json["Payload"]["Descrip"], {})
			end
			return
		end
	elseif request_method == "PUT" then
		local result = false
		local data_table = {}
		local data_str = ""
		if payload_json["RuleType"] == "TimerRule" then
			data_table, result = update_rule_group(request_body)
			if result ~= 0 then
				g_report_event.report_status(msg_id, result, 'Failure', data_table)
			else
				g_report_event.report_status(msg_id, result, 'Success', data_table)
			end
			return
		elseif payload_json["RuleType"] == "LinkageRule" then
			data_str, result = g_cmd_micro.micro_put(linkage_ser,request_body)
			if result == false then
				local return_json = cjson.decode(data_str)
				g_report_event.report_status(msg_id, return_json["Payload"]["Result"], return_json["Payload"]["Descrip"], {})
			end
			return
		elseif payload_json["RuleType"] == "DevopsRule" then
			data_str, result = g_cmd_micro.micro_put(devops_ser,request_body)
			if result == false then
				local return_json = cjson.decode(data_str)
				g_report_event.report_status(msg_id, return_json["Payload"]["Result"], return_json["Payload"]["Descrip"], {})
			end
			return
		end
	elseif request_method == "DELETE" then
		local result = false
		local data_table = {}
		local data_str = ""
		if payload_json["RuleType"] == "TimerRule" then
			data_table, result = delete_rule_group(request_body)
			if result ~= 0 then
				g_report_event.report_status(msg_id, result, 'Failure', data_table)
			else
				g_report_event.report_status(msg_id, result, 'Success', data_table)
			end
			return
		elseif payload_json["RuleType"] == "LinkageRule" then
			data_str, result = g_cmd_micro.micro_delete(linkage_ser,request_body)
			if result == false then
				local return_json = cjson.decode(data_str)
				g_report_event.report_status(msg_id, return_json["Payload"]["Result"], return_json["Payload"]["Descrip"], {})
			end
			return
		elseif payload_json["RuleType"] == "DevopsRule" then
			data_str, result = g_cmd_micro.micro_delete(devops_ser,request_body)
			if result == false then
				local return_json = cjson.decode(data_str)
				g_report_event.report_status(msg_id, return_json["Payload"]["Result"], return_json["Payload"]["Descrip"], {})
			end
			return
		end
	end
end

function m_rule_handle.add_handle(request_method, request_body)
	local request_table = {request_method, request_body}
	
	while true do
		if not g_rule_handle_body_table_locker then
			g_rule_handle_body_table_locker = true
			table.insert(g_rule_handle_body_table, request_table)
			g_rule_handle_body_table_locker = false
			break
		else
			ngx.sleep(0.01)
		end
	end
end

local function remove_table(base, remove)
    local new_table = {}
    for k, v in ipairs(base) do
        local find_key = false
        for rk, rv in ipairs(remove) do
            if rv == k then
                find_key = true
                break
            end
        end
        if not find_key then
            table.insert(new_table, v)
        end
    end
    return new_table
end

function m_rule_handle.rule_handle_thread()
	if g_is_rule_handle_timer_running == false then
		g_is_rule_handle_timer_running = true
		local want_remove = {}
		for i, v in ipairs(g_rule_handle_body_table) do
			local request_method = v[1]
			local request_body = v[2]

			http_method(request_method, request_body)
			table.insert(want_remove, i)
		end
		---remove table what has been handle
		if next(want_remove) ~= nil then
			while true do
				if not g_rule_handle_body_table_locker then
					g_rule_handle_body_table_locker = true
					g_rule_handle_body_table = remove_table(g_rule_handle_body_table, want_remove)
					g_rule_handle_body_table_locker = false
					break
				else
					ngx.sleep(0.01)
				end
			end
		end
		g_is_rule_handle_timer_running = false
	end
end

return m_rule_handle
