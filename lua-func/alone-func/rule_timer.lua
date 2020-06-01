local m_rule_timer = {}

--load module
local g_rule_common = require("alone-func.rule_common")
local g_exec_rule = require("alone-func.exec_rule")


--定时任务要执行的方法
function m_rule_timer.exec_rule_loop()
    --执行所有策略
    local has_failed = g_exec_rule.exec_all_rules()

    m_rule_timer.refresh_rule_timer(has_failed)
end

--更新定时任务下次执行的时间，设置到nginx
function m_rule_timer.refresh_rule_timer(has_failed)
    --获取定时任务下次执行的时间
    local interval, time_err = g_rule_common.get_next_loop_interval()
    if time_err == false then
        ngx.log(ngx.ERR,"get next rule loop timer fail ")
        interval = 10
    end

    if has_failed == true then
        --有策略执行出错，重试时间
        interval = 180
    end
    ngx.log(ngx.INFO,"next loop timeout: ",interval)
    --interval = 10

    --设置后续执行定时任务的时间
    local ok,err = ngx.timer.at(interval, m_rule_timer.exec_rule_loop)
    if not ok then
        ngx.log(ngx.ERR,"rule running failure")
        return
    end
end

return m_rule_timer