local m_cmd_sync = {}

--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_exec_rule = require("alone-func.exec_rule")
local g_rule_timer = require("alone-func.rule_timer")
local g_linkage_sync = require("alone-func.linkage_sync")

--function define
local function check_cmd_input(table)
	if table["DevType"] ~= nil then
		if type(table["DevType"]) ~= "string" then
			ngx.log(ngx.ERR,"DevType type err")
			return "DevType type err", false
        end
    else
        ngx.log(ngx.ERR,"DevType not exist")
        return "DevType not exist", false
	end

	if table["DevId"] ~= nil then
		if type(table["DevId"]) ~= "number" then
			ngx.log(ngx.ERR,"DevId type err")
			return "DevId type err", false
		end

		if table["DevId"] <= 0 then
			return "DevId <= 0", false
        end
    else
        ngx.log(ngx.ERR,"DevId not exist")
        return "DevId not exist", false
	end

	if table["DevChannel"] ~= nil then
		if type(table["DevChannel"]) ~= "number" then
			ngx.log(ngx.ERR,"DevChannel type err")
			return "DevChannel type err", false
		end

		if table["DevChannel"] <= 0 then
			return "DevChannel <= 0", false
        end
    else
        ngx.log(ngx.ERR,"DevChannel not exist")
        return "DevChannel not exist", false
	end

	if table["Method"] ~= nil then
		if type(table["Method"]) ~= "string" then
			ngx.log(ngx.ERR,"Method type err")
			return "Method type err", false
        end
    else
        ngx.log(ngx.ERR,"Method not exist")
        return "Method not exist", false
	end

	if table["In"] ~= nil then
		if type(table["In"]) ~= "table" then
			ngx.log(ngx.ERR,"CmdParam type err")
			return "In type err", false
		end
	end

	return "", true
end

--设置手动命令
local function set_cmd_to_rule(dev_type, dev_id, dev_channel, cmd_method, param)
    local rule_table = {}
    local uuid_str =  string.format("%s-%d-%d-%s", dev_type, dev_id, dev_channel, cmd_method)

    rule_table["RuleUuid"]  = uuid_str
    rule_table["DevType"]   = dev_type
    rule_table["DevId"]     = dev_id
    rule_table["DevChannel"]= dev_channel
    rule_table["Method"]    = cmd_method
    rule_table["Priority"]  = g_rule_common.cmd_priority
    rule_table["RuleParam"] = param
    rule_table["StartTime"] = '00:00:00'
    rule_table["EndTime"]   = '24:00:00'
    rule_table["StartDate"] = '2019-01-01'
    rule_table["EndDate"]   = '2119-01-01'
    
    return rule_table
end

--手动命令插入策略表
function m_cmd_sync.insert_cmd_to_ruletable(cmd_json)
    local cmd_table = cjson.decode(cmd_json)
    local res, err = check_cmd_input(cmd_table)
    if err == false then
        return false
    end

    local dev_type = cmd_table["DevType"]
    local dev_id = cmd_table["DevId"]
    local dev_channel = cmd_table["DevChannel"]
    local cmd_method = cmd_table["Method"]
    local param =  cmd_table["In"]
    local rule_table = set_cmd_to_rule(dev_type, dev_id, dev_channel, cmd_method, param)
	
    local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(rule_table["RuleUuid"])
    if qerr then
        ngx.log(ngx.ERR," ", qres,qerr)
        return false
    end

    if next(qres) == nil then
        ngx.log(ngx.INFO,"insert new cmd to rule table")
        local res,err = g_sql_app.insert_rule_tbl(rule_table)
        if err then
            ngx.log(ngx.ERR," ", res,err)
            return false
        end
    else
        ngx.log(ngx.INFO,"cmd exist in rule table, update")
        local res,err = g_sql_app.update_rule_tbl(rule_table["RuleUuid"], rule_table)
        if err then
            ngx.log(ngx.ERR," ", res,err)
            return false
        end
    end
    
    --执行一次该方法的策略,停止自动策略执行
	g_exec_rule.exec_rules_by_method(dev_type, dev_id, dev_channel, cmd_method)
	
	return true
end

--从策略表删除手动命令
function m_cmd_sync.delete_cmd_from_ruletable(cmd_json)
    local cmd_table = cjson.decode(cmd_json)
    local res, err = check_cmd_input(cmd_table)
    if err == false then
        return false
    end

    local dev_type = cmd_table["DevType"]
    local dev_id = cmd_table["DevId"]
    local dev_channel = cmd_table["DevChannel"]
    local cmd_method = cmd_table["In"]["Method"]

    local uuid_str =  string.format("%s-%d-%d-%s", dev_type, dev_id, dev_channel, cmd_method)
    local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(uuid_str)
    if qerr then
        ngx.log(ngx.ERR," ", qres,qerr)
        return false
    end
    if next(qres) == nil then
        ngx.log(ngx.ERR,"cmd not exist")
        return false
    else
        ngx.log(ngx.INFO,"delete rule")
        --按UUID删除
        local res,err = g_sql_app.delete_rule_tbl_by_uuid(uuid_str)
        if err then
            ngx.log(ngx.ERR," ", res,err)
            return false
        end
    end

    --执行一次该方法的策略，恢复自动策略执行
    g_exec_rule.exec_rules_by_method(dev_type, dev_id, dev_channel, cmd_method)
    
    --更新定时任务间隔
    g_rule_timer.refresh_rule_timer()
	
    return true
end

return m_cmd_sync