local m_cmd_sync = {}

--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_exec_rule = require("alone-func.exec_rule")

--function define
--设置手动命令
local function set_cmd_to_rule(dev_type, dev_id, dev_channel, cmd_method)
    local rule_table = {}
    local uuid_str =  string.format("%s-%d-%d-%s", dev_type, dev_id, dev_channel, cmd_method)

    rule_table["RuleUuid"]  = uuid_str
    rule_table["DevType"]   = dev_type
    rule_table["DevId"]     = dev_id
    rule_table["ChannelId"] = dev_channel
    rule_table["Method"]    = cmd_method
    rule_table["Priority"]  = g_rule_common.cmd_priority
    rule_table["RuleModule"]= g_rule_common.depend_rule_module(dev_type)
    rule_table["RuleParam"] = {}
    rule_table["StartTime"] = '00:00:00'
    rule_table["EndTime"]   = '24:00:00'
    rule_table["StartDate"] = '2019-01-01'
    rule_table["EndDate"]   = '2119-01-01'
    
    return rule_table
end

--手动命令插入策略表
function m_cmd_sync.insert_cmd_to_ruletable(dev_type, dev_id, dev_channel, cmd_method)
    local rule_table = set_cmd_to_rule(dev_type, dev_id, dev_channel, cmd_method)
	
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
function m_cmd_sync.delete_cmd_from_ruletable(dev_type, dev_id, dev_channel, cmd_method)
    local uuid_str =  string.format("%s-%d-%d-%s", dev_type, dev_id, dev_channel, cmd_method)
    local qres,qerr = g_sql_app.query_rule_tbl_by_uuid(uuid_str)
    if qerr then
        ngx.log(ngx.ERR," ", qres,qerr)
        return false
    end
    if next(qres) == nil then
        ngx.log(ngx.ERR,"cmd not exist")
        return true
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