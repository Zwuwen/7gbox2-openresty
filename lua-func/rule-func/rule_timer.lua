local m_rule_timer = {}

--load module
local g_rule_common = require("rule-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local g_exec_rule = require("rule-func.exec_rule")

local next_timer = 0

--定时任务要执行的方法
function m_rule_timer.exec_rule_loop()
    --执行所有策略
    local has_failed = g_exec_rule.exec_all_rules()
    if has_failed == "ignore" then
        --忽略定时器
        return
    end

    m_rule_timer.refresh_rule_timer(has_failed)
end

--更新定时任务下次执行的时间，设置到nginx
function m_rule_timer.refresh_rule_timer(has_failed)
    ngx.update_time()
    --获取定时任务下次执行的时间
    local interval, time_err = g_rule_common.get_next_loop_interval()
    if time_err == false then
        ngx.log(ngx.ERR,"get next rule loop timer fail ")
    end

    if has_failed == true then
        --有策略执行出错，重试时间
        local retry_interval = 180 - (math.floor(ngx.now()) % 60)
        ngx.log(ngx.INFO,"next retry loop timeout: ",retry_interval)

        if interval == nil then
            interval = retry_interval
        end
        interval = math.min(interval, retry_interval)
    end

    if interval == nil then
        ngx.log(ngx.INFO,"no timer, do not set new timer")
        return
    end

    local tmp_next_timer = math.floor(ngx.now()) + interval
    local timer_interval = math.abs(next_timer - tmp_next_timer)
    if timer_interval < 3 then
        ngx.log(ngx.INFO,"same timer, do not set new timer")
        return
    end
    
    ngx.log(ngx.INFO,"next loop timeout: ",interval)
    --interval = 10

    --设置后续执行定时任务的时间
    if ngx.worker.id() == 0 then
        next_timer = tmp_next_timer
        local ok,err = ngx.timer.at(interval, m_rule_timer.exec_rule_loop)
        if not ok then
            ngx.log(ngx.ERR,"set rule timer failure: ", err)
            ngx.log(ngx.INFO,"timer running count: ", ngx.timer.running_count())
            ngx.log(ngx.INFO,"timer pending count: ", ngx.timer.pending_count())
            return
        end
    end
end

function m_rule_timer.clear_rule_running_on_restart()
    local second = g_rule_common.get_system_running_time()

    --系统是刚刚启动时清除原来的运行状态
    if second < 100 then
        local sql_str = string.format("update run_rule_tbl set running=0")
        local res, err = g_sql_app.exec_sql(sql_str)
        if err then
            ngx.log(ngx.ERR," ", res, err)
            return
        end

        local sql_str = string.format("update dev_status_tbl set is_dft=0")
        local res, err = g_sql_app.exec_sql(sql_str)
        if err then
            ngx.log(ngx.ERR," ", res, err)
            return
        end
    end
end

return m_rule_timer