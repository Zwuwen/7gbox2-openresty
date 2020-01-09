local m_cmd_sync = {}

--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_exec_rule = require("alone-func.exec_rule")


--function define
--获取dev_status_tbl-auto_mode
function m_cmd_sync.get_auto_mode(dev_type, dev_id)
    local auto_mode = 0
    local res, err = g_sql_app.query_dev_status_tbl(dev_id)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        return 0, false
    end
    if next(res) == nil then
        ngx.log(ngx.ERR,"device id not exist")
        return 0, false
    else
		auto_mode = res[1]["auto_mode"]
    end
    
    ngx.log(ngx.INFO,"check auto_mode: ", auto_mode)
    return auto_mode, true
end

--手动模式，停止策略
local function cmd_stop_rule_running(dev_type, dev_id)
    local res, err = m_cmd_sync.get_auto_mode(dev_type, dev_id)
    if err == false then
        ngx.log(ngx.ERR,"get auto_mode err")
        return false
    end
    
    if res ~= 0 then
        ngx.log(ngx.ERR,"cmd not running, exit")
        return false
    end
    --auto_mode == 0
    --策略
    local sql_str = string.format("update run_rule_tbl set running=0 where dev_type=\'%s\' and dev_id=%d", dev_type, dev_id)
    local res, err = g_sql_app.exec_sql(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        ngx.log(ngx.ERR,"update cmd rule running err")
        return false
    end
    return true
end

--自动模式，执行策略
local function cmd_restore_rule_running(dev_type, dev_id)
    local res, err = m_cmd_sync.get_auto_mode(dev_type, dev_id)
    if err == false then
        ngx.log(ngx.ERR,"get auto_mode err")
        return false
    end
    
    if res == 0 then
        ngx.log(ngx.ERR,"cmd is still running, ignore time rule")
        return false
    end
    --auto_mode == 1
    --执行设备的策略
    g_exec_rule.exec_rules_by_devid(dev_type, dev_id)
    return true
end

--自动/手动模式，策略
--输入：
--  dev_type
--  dev_id
--  status：
--      1：切换到手动，禁止策略执行
--      0：切换到自动，执行策略
--输出：
--  false：设置失败
--  true：设置成功
function m_cmd_sync.cmd_start_stop_rule(dev_type, dev_id, status)
    local rt = false
    if status == 1 then
        rt = cmd_stop_rule_running(dev_type, dev_id)
    elseif status == 0 then
        rt = cmd_restore_rule_running(dev_type, dev_id)
    else
        ngx.log(ngx.ERR,"input err")
        rt = false
    end
    return rt
end


return m_cmd_sync