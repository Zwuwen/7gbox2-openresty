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

	if table["Priority"] ~= nil then
		if type(table["Priority"]) ~= "number" then
			ngx.log(ngx.ERR,"Priority type err")
			return "Priority type err", false
		end

		if table["Priority"] <= 0 then
			return "Priority <= 0", false
		end
	end

	if table["Actions"] ~= nil then
		if type(table["Actions"]) ~= "table" then
			ngx.log(ngx.ERR,"Actions type err")
			return "Actions type err", false
		end
	end

	if table["Method"] ~= nil then
		if type(table["Method"]) ~= "string" then
			ngx.log(ngx.ERR,"Method type err")
			return "Method type err", false
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

---------------------------------------------------------------------------------
--method级增删改查方法
---------------------------------------------------------------------------------
--POST 插入策略
local function create_rule(req_payload)
	local json_param = cjson.decode(req_payload)

	--插入
	for i,json_obj in ipairs(json_param["Rules"]) do
		--[[
		local res,err = check_rule_input(json_obj)
		if err == false then
			ngx.log(ngx.ERR," ", res)
			return res, false
		end
		--]]

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
		--g_rule_timer.refresh_rule_timer()
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
				return "rule not exist", false
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
				--g_rule_timer.refresh_rule_timer()
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
			return "rule not exist", false
		else
			ngx.log(ngx.INFO,"delete rule: ", payload["DevType"]..", "..payload["DevId"])
			local res,err = g_sql_app.delete_rule_tbl_by_dev_id(payload["DevType"], payload["DevId"])
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return err, false
			end
		end		

		--更新定时任务间隔
		--g_rule_timer.refresh_rule_timer()
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

		if json_obj["Priority"] ~= nil then
			if (json_obj["Priority"] < g_rule_common.time_priority_h or 
				json_obj["Priority"] > g_rule_common.time_priority_l)
			then
				ngx.log(ngx.ERR,"time rule priority is 8~13")
				return "time rule priority should be 8~13", false
			end
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
		--g_rule_timer.refresh_rule_timer()
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

---------------------------------------------------------------------------------
--增删改查方法封装
---------------------------------------------------------------------------------
--插入策略组
local function create_rule_group(all_json)
	local all_table = cjson.decode(all_json)
	local payload = all_table["Payload"]

	--
	if (payload["Rules"] == nil) then
		ngx.log(ngx.ERR,"Rules key err")
		return "Rules key err", false
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
			return "input param incomplete", false
		end

		local res,err = check_rule_input(rule_obj)
		if err == false then
			ngx.log(ngx.ERR," ", res)
			return res, false
		end

		--检查json第二层
		local rule_group = {}
		local tmp_rule_group = {}
		if rule_obj["DevType"] == "Lamp" then
			rule_group = {"SetOnOff", "SetBrightness"}
		elseif rule_obj["DevType"] == "InfoScreen" then
			rule_group = {"SetOnOff", "LoadProgram", "SetBrightness", "SetVolume"}
		elseif rule_obj["DevType"] == "IPC-Onvif" then
			rule_group = {"GotoPreset"}
		elseif rule_obj["DevType"] == "Speaker" then
			rule_group = {"PlayProgram"}
		else
			ngx.log(ngx.ERR,"DevType error")
			return "DevType error", false
		end
		ngx.log(ngx.INFO,"rule group require method: ", cjson.encode(rule_group))
				
		for i,action in ipairs(rule_obj["Actions"]) do
			if (action["Method"] == nil) then
				ngx.log(ngx.ERR,"Method key err")
				return "Method key err", false
			end
			if (action["RuleParam"] == nil) then
				ngx.log(ngx.ERR,"RuleParam key err")
				return "RuleParam key err", false
			end
			local res,err = check_rule_input(action)
			if err == false then
				ngx.log(ngx.ERR," ", res)
				return res, false
			end

			table.insert(tmp_rule_group, action["Method"])
		end
		ngx.log(ngx.INFO,"input rule group method: ", cjson.encode(tmp_rule_group))

		for i,method in ipairs(rule_group) do
			local err = g_rule_common.is_include(method, tmp_rule_group)
			if err == false then
				ngx.log(ngx.ERR,"rule group method not complete")
				return "rule group method not complete", false
			end

			for i,tmp_method in ipairs(tmp_rule_group) do
				if method == tmp_method then
					table.remove(tmp_rule_group, i)
				end
			end
		end
		if next(tmp_rule_group) ~= nil then
			ngx.log(ngx.ERR,"rule group method too much")
			return "rule group method too much", false
		end

		--query
		local sql_str = string.format("select * from run_rule_tbl where rule_uuid like \'7G-%s-time-%%\'", rule_obj["RuleUuid"])
		local res,err = g_sql_app.query_table(sql_str)
		if err then
			ngx.log(ngx.ERR," ", res,err)
			return err, false
		end
		if next(res) ~= nil then
			ngx.log(ngx.ERR,"rule exist")
			return "rule exist", false
		end

		--插入策略
		local tmp_payload = {}
		local tmp_rule = {}
		tmp_rule["DevType"]    = rule_obj["DevType"]
		tmp_rule["DevId"]      = rule_obj["DevId"]
		tmp_rule["DevChannel"] = rule_obj["DevChannel"]
		tmp_rule["Priority"]   = rule_obj["Priority"]
		tmp_rule["StartDate"]  = rule_obj["StartDate"]
		tmp_rule["EndDate"]    = rule_obj["EndDate"]
		tmp_rule["StartTime"]  = rule_obj["StartTime"]
		tmp_rule["EndTime"]    = rule_obj["EndTime"]

		for i,action in ipairs(rule_obj["Actions"]) do
			tmp_rule["RuleUuid"]  = "7G-"..rule_obj["RuleUuid"].."-time-"..tostring(i)	--生成子uuid
			tmp_rule["Method"]    = action["Method"]
			tmp_rule["RuleParam"] = action["RuleParam"]
			tmp_payload["RuleType"] = payload["RuleType"]
			tmp_payload["Rules"] = {}
			table.insert(tmp_payload["Rules"], tmp_rule)

			local tmp_rule_json = cjson.encode(tmp_payload)
			ngx.log(ngx.INFO,"insert sub json: ", tmp_rule_json)
			local res,err = create_rule(tmp_rule_json)
			if err == false then
				ngx.log(ngx.ERR,"insert rule fail")
				return res, false
			end
		end
	end
	--更新定时任务间隔
	g_rule_timer.refresh_rule_timer()

	return "", true
end

--删除策略组
local function delete_rule_group(all_json)
	local all_table = cjson.decode(all_json)
	if (all_table["Payload"] == nil) then
		ngx.log(ngx.ERR,"Payload key err")
		return "Payload key err", false
	end

	local payload = all_table["Payload"]
	if (payload["Method"] == nil) then
		ngx.log(ngx.ERR,"Method key err")
		return "Method key err", false
	end

	if payload["Method"] == "DelByRuleUuid" then
		if (payload["Rules"] == nil) then
			ngx.log(ngx.ERR,"Rules key err")
			return "Rules key err", false
		else
			if type(payload["Rules"]) ~= "table" then
				ngx.log(ngx.ERR,"Rules type err")
				return "Rules type err", false
			end
		end

		--获取所有要删除的UUID
		local uuid_group = {}
		for i,rule_uuid in ipairs(payload["Rules"]) do
			if type(rule_uuid) ~= "string" then
				ngx.log(ngx.ERR,"RuleUuid type err")
				return "RuleUuid type err", false
			end

			local sql_str = string.format("select * from run_rule_tbl where rule_uuid like \'7G-%s-time-%%\'", rule_uuid)
			local res,err = g_sql_app.query_table(sql_str)
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return err, false
			end
			if next(res) == nil then
				ngx.log(ngx.ERR,"rule not exist")
				return "rule not exist", false
			end
		
			for i,rule in ipairs(res) do
				table.insert(uuid_group, rule["rule_uuid"])
			end
		end

		--删除
		local sub_rules = {}
		sub_rules["Rules"] = uuid_group
		local sub_table = {}
		sub_table["Method"] = payload["Method"]
		sub_table["Payload"] = sub_rules

		local sub_json = cjson.encode(sub_table)
		ngx.log(ngx.INFO,"delete by UUID sub json: ", sub_json)
		local res, err = delete_rule(sub_json)

		--更新定时任务间隔
		g_rule_timer.refresh_rule_timer()
		return res, err
	elseif payload["Method"] == "DelByDevId" then
		local sub_table = {}
		sub_table["Method"] = payload["Method"]
		sub_table["Payload"] = payload

		local sub_json = cjson.encode(sub_table)
		ngx.log(ngx.INFO,"delete by device sub json", sub_json)
		local res, err = delete_rule(sub_json)

		--更新定时任务间隔
		g_rule_timer.refresh_rule_timer()
		return res, err
	else
		ngx.log(ngx.ERR,"delete rules, method error ")
		return "delete rules, method error", false
	end
end

--更新策略组
local function update_rule_group(all_json)
	local all_table = cjson.decode(all_json)
	local payload = all_table["Payload"]

	--
	if (payload["Rules"] == nil) then
		ngx.log(ngx.ERR,"Rules key err")
		return "Rules key err", false
	end
	for i,rule_obj in ipairs(payload["Rules"]) do
		--检查json第一层
		if (rule_obj["RuleUuid"] == nil) then
			ngx.log(ngx.ERR,"please input rule uuid")
			return "please input rule uuid", false
		end

		local res,err = check_rule_input(rule_obj)
		if err == false then
			ngx.log(ngx.ERR," ", res)
			return res, false
		end

		
		if (rule_obj["Actions"] ~= nil) and
		next(rule_obj["Actions"]) ~= nil
		then
			--有Actions，单独更新按方法分解的每一条
			--检查json第二层
			for i,action in ipairs(rule_obj["Actions"]) do
				if (action["Method"] == nil) then
					ngx.log(ngx.ERR,"Method key err")
					return "Method key err", false
				end
				if (action["RuleParam"] == nil) then
					ngx.log(ngx.ERR,"RuleParam key err")
					return "RuleParam key err", false
				end
				local res,err = check_rule_input(action)
				if err == false then
					ngx.log(ngx.ERR," ", res)
					return res, false
				end

				--查询该method策略的rule_uuid
				local sql_str = string.format("select * from run_rule_tbl where rule_uuid like \'7G-%s-time-%%\' and method=\'%s\'", rule_obj["RuleUuid"], action["Method"])
				local res,err = g_sql_app.query_table(sql_str)
				if err then
					ngx.log(ngx.ERR," ", res,err)
					return err, false
				end
				if next(res) == nil then
					ngx.log(ngx.ERR,"rule not exist")
					return "rule not exist", false
				else
					local sub_table = {}
					sub_table["Rules"] = {}
					local tmp_rule_obj = g_rule_common.table_clone(rule_obj)
					table.insert(sub_table["Rules"], tmp_rule_obj)
	
					for i,rule in ipairs(res) do
						--清除该策略运行状态为0
						local run_flag = {}
						run_flag["Running"] = 0
						local clr_res,err = g_sql_app.update_rule_tbl(rule["rule_uuid"], run_flag)
						if err then
							ngx.log(ngx.ERR," ",clr_res.."  err msg: ",err)
							return "clear rule running false", false
						end

						--组装更新数据
						sub_table["Rules"][1]["RuleUuid"] = rule["rule_uuid"]
						sub_table["Rules"][1]["Method"] = action["Method"]
						sub_table["Rules"][1]["RuleParam"] = action["RuleParam"]
	
						local sub_json = cjson.encode(sub_table)
						ngx.log(ngx.INFO,"update sub json: ", sub_json)
						local res,err = update_rule(sub_json)
						if err == false then
							ngx.log(ngx.ERR,"update rule fail")
							return res, false
						end
					end
				end
			end			
		else
			--无Actions，只更新各分解策略的公共信息
			local sql_str = string.format("select * from run_rule_tbl where rule_uuid like \'7G-%s-time-%%\'", rule_obj["RuleUuid"])
			local res,err = g_sql_app.query_table(sql_str)
			if err then
				ngx.log(ngx.ERR," ", res,err)
				return err, false
			end
			if next(res) == nil then
				ngx.log(ngx.ERR,"rule not exist")
				return "rule not exist", false
			else
				local sub_table = {}
				sub_table["Rules"] = {}
				local tmp_rule_obj = g_rule_common.table_clone(rule_obj)
				table.insert(sub_table["Rules"], tmp_rule_obj)

				for i,rule in ipairs(res) do
					sub_table["Rules"][1]["RuleUuid"] = rule["rule_uuid"]

					local sub_json = cjson.encode(sub_table)
					ngx.log(ngx.INFO,"update sub json: ", sub_json)
					local res,err = update_rule(sub_json)
					if err == false then
						ngx.log(ngx.ERR,"update rule fail")
						return res, false
					end
				end
			end
		end
	end
	--更新定时任务间隔
	g_rule_timer.refresh_rule_timer()

	return "", true
end

--一组子时间策略列表恢复成一个时间策略
local function recover_rule_group(rule_tables)
	local new_tables = {}
	local uuid_set = {}

	for i,rule_table in ipairs(rule_tables) do
		--获取策略组真正的RuleUuid（去除前缀 后缀）
		--目前一个设备时间策略的方法数是个位数，所以后缀减7就可以
		local uuid = string.sub(rule_table["RuleUuid"], 4, string.len(rule_table["RuleUuid"])-7)
		ngx.log(ngx.DEBUG,"recover time rule, next uuid: ", uuid)

		if not g_rule_common.is_include(uuid, uuid_set) then
			--新UUID，插入新策略
			ngx.log(ngx.DEBUG,"insert new")
			rule_table["RuleUuid"] = uuid
			local tmp_actions = {}
			tmp_actions["Method"] = rule_table["Method"]
			tmp_actions["RuleParam"] = rule_table["RuleParam"]
			rule_table["Actions"] = {}
			table.insert(rule_table["Actions"], tmp_actions)
			
			table.insert(new_tables, rule_table)
			table.insert(uuid_set, uuid)
		else
			--方法添加到已有策略
			ngx.log(ngx.DEBUG,"add method")
			for i,new_table in ipairs(new_tables) do
				if new_table["RuleUuid"] == uuid then
					local tmp_actions = {}
					tmp_actions["Method"] = rule_table["Method"]
					tmp_actions["RuleParam"] = rule_table["RuleParam"]
					table.insert(new_table["Actions"], tmp_actions)
				end
			end
		end
	end

	--删除子策略的Method,RuleParam
	for i,new_table in ipairs(new_tables) do
		new_table["Method"] = nil
		new_table["RuleParam"] = nil
	end
	return new_tables
end

--查询策略组
local function select_rule_group(all_json)
	local all_table = cjson.decode(all_json)
	local payload = all_table["Payload"]

	--查询时间策略
	--分解策略组rule_uuid到子UUID
	if payload["Rules"] ~= nil then
		local tmp_uuids = {}
		for i,uuid in ipairs(payload["Rules"]) do
			local sql_str = string.format("select * from run_rule_tbl where rule_uuid like \'7G-%s-time-%%\'", uuid)
			local sub_rules,err = g_sql_app.query_table(sql_str)
			if err then
				ngx.log(ngx.ERR," ", sub_rules,err)
				return err, false
			end
			if next(sub_rules) == nil then
				--无
			else
				for i,sub_rule in ipairs(sub_rules) do
					table.insert(tmp_uuids, sub_rule["rule_uuid"])
				end
			end
		end

		payload["Rules"] = nil
		payload["Rules"] = tmp_uuids
	end
	local sub_table, err = select_rule(cjson.encode(payload))
	if err == false then
		ngx.log(ngx.ERR,"query time rule fail")
		return sub_table, false
	end

	--合并rule group
	local f_rule_array = {}
	if payload["Rules"] ~= nil then
		--uuid
		f_rule_array = recover_rule_group(sub_table)
	elseif payload["Devices"] ~= nil then
		--dev
		for i,dev_rule in ipairs(sub_table) do
			local tmp_dev_rule = recover_rule_group(dev_rule)
			table.insert(f_rule_array, tmp_dev_rule)
		end
	else
		payload["RuleType"] = nil	--删除RuleType
		if next(payload) == nil then
			--body为空：获取全部策略
			f_rule_array = recover_rule_group(sub_table)
		else
			ngx.log(ngx.ERR,"query method err")
			return "query method err", false
		end
	end

	ngx.log(ngx.ERR,"query payload: ", cjson.encode(f_rule_array))
	return f_rule_array, true	
end

---------------------------------------------------------------------------------
---------------------------生成请求的http响应数据--------------------------------
---------------------------------------------------------------------------------
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

---------------------------------------------------------------------------------
--------------------------------main function------------------------------------
---------------------------------------------------------------------------------
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

local all_json = {}
if pcall(cjson.decode, request_body) then
	-- 没有错误
	all_json = cjson.decode(request_body)
else
	-- 错误
	ngx.log(ngx.ERR,"json format error")
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"json format error\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	return
end

if all_json["Token"] ~= nil then
	if type(all_json["Token"]) ~= "string" then
		ngx.log(ngx.ERR,"Token type err")
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"Token type err\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		return
	end
end

if all_json["MsgId"] ~= nil then
	if type(all_json["MsgId"]) ~= "string" then
		ngx.log(ngx.ERR,"MsgId type err")
		local json_str = '{\n\"errcode\":400,\n \"msg\":\"MsgId type err\",\n\"payload\":{}\n}'
		ngx.say(json_str)
		return
	end
end
local msg_id = all_json["MsgId"]

if all_json["Payload"] == nil then
	ngx.log(ngx.ERR,"Rule body has no Payload")
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"Rule body has no Payload\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	return
end

local payload_json = all_json["Payload"]

if type(payload_json["RuleType"]) ~= "string" then
	ngx.log(ngx.ERR,"RuleType type err")
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"RuleType type err\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	return
end
if payload_json["RuleType"] ~= "TimerRule" and payload_json["RuleType"] ~= "LinkageRule" then
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
	if payload_json["RuleType"] == "TimerRule" then
		data_table, result = select_rule_group(request_body)
	elseif payload_json["RuleType"] == "LinkageRule" then
		data_str, result = g_cmd_micro.micro_get(linkage_ser,request_body)
		local return_json = cjson.decode(data_str)
		local gw = g_sql_app.query_dev_info_tbl(0)
		return_json["GW"] = gw[1]["sn"]
		return_json["Event"] = "ReqStsUpload"
		local json_body = cjson.decode(request_body)
		return_json["MsgId"] = json_body["MsgId"]
		local res_str = cjson.encode(return_json)
		ngx.say(res_str)
		return_json["Event"] = "ResultUpload"
		report_event.method_respone(return_json)
		return
	end
	if result == false then
		local json_str = encode_select_response(1, 'Failure', data_table)
		ngx.say(json_str)
		g_report_event.report_status(msg_id, 1, 'Failure', data_table)
	else
		local json_str = encode_select_response(0, 'Success', data_table)
		ngx.say(json_str)
		g_report_event.report_status(msg_id, 0, 'Success', data_table)
	end
elseif request_method == "POST" then
	local result = false
	local data_table = {}
	local data_str = ""
	if payload_json["RuleType"] == "TimerRule" then
		data_table, result = create_rule_group(request_body)
	elseif payload_json["RuleType"] == "LinkageRule" then
		data_str, result = g_cmd_micro.micro_post(linkage_ser,request_body)
		local return_json = cjson.decode(data_str)
		local gw = g_sql_app.query_dev_info_tbl(0)
		return_json["GW"] = gw[1]["sn"]
		return_json["Event"] = "ReqStsUpload"
		local json_body = cjson.decode(request_body)
		return_json["MsgId"] = json_body["MsgId"]
		local res_str = cjson.encode(return_json)
		ngx.say(res_str)
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
	if payload_json["RuleType"] == "TimerRule" then
		data_table, result = update_rule_group(request_body)
	elseif payload_json["RuleType"] == "LinkageRule" then
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
	if payload_json["RuleType"] == "TimerRule" then
		data_table, result = delete_rule_group(request_body)
	elseif payload_json["RuleType"] == "LinkageRule" then
		data_str, result = g_cmd_micro.micro_delete(linkage_ser,request_body)
		local return_json = cjson.decode(data_str)
		local gw = g_sql_app.query_dev_info_tbl(0)
		return_json["GW"] = gw[1]["sn"]
		return_json["Event"] = "ReqStsUpload"
		local json_body = cjson.decode(request_body)
		return_json["MsgId"] = json_body["MsgId"]
		local res_str = cjson.encode(return_json)
		ngx.say(res_str)
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
