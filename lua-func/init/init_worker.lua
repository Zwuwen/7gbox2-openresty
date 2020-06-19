--load module
local g_rule_timer = require("alone-func.rule_timer")
local g_exec_heart = require("init.init_heartbeat")
local g_event_report = require("event-func.event_report")
local g_cmd_handle_model = require("cmd-func.cmd_handle_model")
local heart_time = 60
local regular_report_time = 300
local plat_report_time = 30

--------------------------------main function----------------------------
--ResultUpload状态异步回复
local ok,err = ngx.timer.every(0.5, g_event_report.method_respone_handle)
if not ok then
    ngx.log(ngx.ERR,"rule running failure, err:", err)
    return
end

--cmd请求的异步处理
local ok,err = ngx.timer.every(0.5, g_cmd_handle_model.cmd_handle_thread)
if not ok then
    ngx.log(ngx.ERR,"cmd handle thread, err:", err)
    return
end

--定时任务，执行策略
--设置启动后第一次执行定时任务的时间
local ok,err = ngx.timer.at(5, g_rule_timer.exec_rule_loop)
if not ok then
    ngx.log(ngx.ERR,"rule running failure")
    return
end

--定时任务，微服务心跳
local exec_heart_loop = function()
    g_exec_heart.time_task_exec()
end
local ok,err = ngx.timer.every(heart_time,exec_heart_loop)
if not ok then
    ngx.log(ngx.ERR,"heart running failure")
    return
end

--定时上报数据给平台
local regular_report_loop = function()
    local message ={}
    message["Event"] = "PlatStatus"
    message["Status"] = 1
    g_event_report.platform_online_event(message)
end

local ok,err = ngx.timer.every(regular_report_time,regular_report_loop)
if not ok then
    ngx.log(ngx.ERR,"regular report running failure")
    return
else
    ngx.log(ngx.ERR,"regular report running success")
end

--平台心跳
local platform_heart_report_loop = function()
    g_event_report.platform_heart_event()
end

local ok,err = ngx.timer.every(plat_report_time,platform_heart_report_loop)
if not ok then
    ngx.log(ngx.ERR,"platform heart report running failure")
    return
else
    ngx.log(ngx.ERR,"platform heart report running success")
end

