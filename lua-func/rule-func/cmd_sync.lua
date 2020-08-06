local m_cmd_sync = {}

--load module
local g_rule_common = require("rule-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_exec_rule = require("rule-func.exec_rule")
local g_rule_timer = require("rule-func.rule_timer")


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
    --取消正在下发的策略及默认执行
    local channel_cnt = g_rule_common.get_dev_channel_cnt(dev_type, dev_id)
    if channel_cnt == nil then
        ngx.log(ngx.ERR,"query dev_channel cnt err")
        return false
    end
    for i=1,channel_cnt do
        g_exec_rule.check_device_rule_idle_status(dev_type, dev_id, i)
    end

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
    local has_failed = false
    local rty_cnt = 0
    while rty_cnt < 3 do
        has_failed = g_exec_rule.exec_rules_by_devid(dev_type, dev_id, false)
        if has_failed ~= true then
            --没有失败
            break
        end
        rty_cnt = rty_cnt + 1
        ngx.log(ngx.ERR,dev_type.."-"..dev_id.." restore automode exec rule fail, retry "..rty_cnt)
    end
    --更新定时任务间隔
    g_rule_timer.refresh_rule_timer(has_failed)
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