local m_linkage_sync = {}

--load module
local g_rule_common = require("rule-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_exec_rule = require("rule-func.exec_rule")
local g_rule_timer = require("rule-func.rule_timer")


--获取设备类型
local function get_devtype(dev_id)
	local dev_type = nil
    local sql_str = string.format("select * from dev_info_tbl where dev_id=%d",dev_id)
    local res,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res,err)
        return "", false
    end
    if next(res) == nil then
        ngx.log(ngx.ERR,"device not exist")
        return "", false
    else
		dev_type = res[1]["dev_type"]
    end
	return dev_type,true
end

--获取dev_status_tbl-linkage_rule
function m_linkage_sync.get_linkage_rule(dev_type, dev_id)
    local linkage_run = 0
    local res, err = g_sql_app.query_dev_status_tbl(dev_id)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        return 0, false
    end
    if next(res) == nil then
        ngx.log(ngx.ERR,"device id not exist")
        return 0, false
    else
		linkage_run = res[1]["linkage_rule"]
    end
    
    ngx.log(ngx.INFO,"check linkage_run: ", linkage_run)
    return linkage_run, true
end

--联动执行，停止策略
local function linkage_stop_rule_running(dev_type, dev_id)
    local res, err = m_linkage_sync.get_linkage_rule(dev_type, dev_id)
    if err == false then
        ngx.log(ngx.ERR,"get linkage_rule err")
        return false
    end
    
    if res ~= 1 then
        ngx.log(ngx.ERR,"linkage not running, exit")
        return false
    end
    --linkage_rule == 1
    --策略
    --上报策略结束
    g_exec_rule.report_dev_end_status(dev_type, dev_id)

    local sql_str = string.format("update run_rule_tbl set running=0 where dev_type=\'%s\' and dev_id=%d", dev_type, dev_id)
    local res, err = g_sql_app.exec_sql(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        ngx.log(ngx.ERR,"update cmd rule running err")
        return false
    end

    --清除设备默认状态标志
    g_rule_common.set_dev_dft_flag(dev_type, dev_id, 0)

    return true
end

--联动取消，执行策略
local function linkage_restore_rule_running(dev_type, dev_id)
    local res, err = m_linkage_sync.get_linkage_rule(dev_type, dev_id)
    if err == false then
        ngx.log(ngx.ERR,"get linkage_rule err")
        return false
    end
    
    if res == 1 then
        ngx.log(ngx.ERR,"linkage is still running, ignore time rule")
        return false
    end
    --linkage_rule == 0
    --执行设备的策略
    local has_failed = g_exec_rule.exec_rules_by_devid(dev_type, dev_id)
    --更新定时任务间隔
    g_rule_timer.refresh_rule_timer(has_failed)
    return true
end

--联动，策略
--输入：
--  dev_type
--  dev_id
--  status：
--      1：联动执行，禁止策略执行
--      0：联动取消，执行策略
--输出：
--  false：设置失败
--  true：设置成功
function m_linkage_sync.linkage_start_stop_rule(dev_type, dev_id, status)
    local rt = false
    if dev_type == nil then
        local res, err = get_devtype(dev_id)
        if err == false then
            return false
        end
        dev_type = res
    end
    
    if status == 1 then
        rt = linkage_stop_rule_running(dev_type, dev_id)
    elseif status == 0 then
        rt = linkage_restore_rule_running(dev_type, dev_id)
    else
        ngx.log(ngx.ERR,"input err")
        rt = false
    end
    return rt
end

return m_linkage_sync