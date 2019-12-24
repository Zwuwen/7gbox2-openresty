local m_linkage_sync = {}

--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_exec_rule = require("alone-func.exec_rule")

--更新linkage_running
local function update_linkage_running(dev_type, dev_id, running)
    local sql_str = string.format("update run_rule_tbl set linkage_running=%d where dev_type=\'%s\' and dev_id=%d", running, dev_type, dev_id)
    
    local res, err = g_sql_app.exec_sql(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        return false
    end
    return true
end

--联动执行，停止策略
local function linkage_stop_rule_running(dev_type, dev_id)
    local err = update_linkage_running(dev_type, dev_id, 1)
    if err == false then
        ngx.log(ngx.ERR,"update linkage_running err")
        return false
    end

    --策略
    local sql_str = string.format("update run_rule_tbl set running=0 where dev_type=\'%s\' and dev_id=%d", dev_type, dev_id)
    local res, err = g_sql_app.exec_sql(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        ngx.log(ngx.ERR,"update cmd rule running err")
        return false
    end

    --删除被中断的手动命令
    local sql_str = string.format("delete from run_rule_tbl where dev_type=\'%s\' and dev_id=%d and priority=%d", dev_type, dev_id, g_rule_common.cmd_priority)
    local res, err = g_sql_app.exec_sql(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        ngx.log(ngx.ERR,"delete cmd err")
        return false
    end

    return true
end

--联动取消，执行策略
local function linkage_restore_rule_running(dev_type, dev_id)
    local err = update_linkage_running(dev_type, dev_id, 0)
    if err == false then
        ngx.log(ngx.ERR,"update linkage_running err")
        return false
    end

    --执行设备的策略
    g_exec_rule.exec_rules_by_devid(dev_type, dev_id)
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