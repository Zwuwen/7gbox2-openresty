--http module
local event_report_M = {version='v1.0.1'}

local g_http = require("common.http.myhttp_M")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_message = require("event-func.message_M")
local event_conf = require("conf.event_conf")
local g_micro = require("cmd-func.cmd_micro")
local g_dev_status = require("dev-status-func.dev_status")
local g_rule_common = require("rule-func.rule_common")
local g_exec_rule = require("rule-func.exec_rule")
local g_linkage = require("rule-func.linkage_sync")
local g_cmd_sync = require("rule-func.cmd_sync")
local g_tstatus = require("rule-func.time_rule_status")
local g_rule_timer = require("rule-func.rule_timer")

local g_result_upload_msg_table = {}
local g_is_result_upload_timer_running = false
local g_result_upload_msg_table_locker = false

--通过HTTP推送数据
local function event_send_message(url, message)
    ngx.log(ngx.ERR,"post to platform url: ",url)
    ngx.log(ngx.ERR,"post to platform message: ",message)
    g_http.init()
    g_http.request_url(url,"POST",message)
    g_http.uninit()
end

----------------------设备上线事件------------------------
--查库获取属性状态
local function get_db_device_message(dev_id)
    local res,err = g_sql_app.query_dev_status_tbl(dev_id)
    if res then
        local attribute = res[1]["attribute"]
        return attribute
    else
        ngx.log(ngx.ERR,"query_dev_status_tbl fail dev_id= ",dev_id)
        return nil
    end
end

function event_report_M.thing_online(devices)
    local dev_list = {}
    for key, value in pairs(devices) do
        local dev_id = value["DevId"]
        local dev_type = value["DevType"]
        --执行该设备的时间策略
        local has_failed = false
        local rty_cnt = 0
        while rty_cnt < 3 do
            has_failed = g_exec_rule.exec_rules_by_devid(dev_type, dev_id, false)
            if has_failed ~= true then
                --没有失败
                ngx.log(ngx.ERR,dev_type.."-"..dev_id.." online exec rule success")
                break
            end
            ngx.sleep(3)
            rty_cnt = rty_cnt + 1
            ngx.log(ngx.ERR,dev_type.."-"..dev_id.." online exec rule fail")
        end
    	--更新定时任务间隔
        g_rule_timer.refresh_rule_timer(has_failed)
        
        --上报属性
        local device_object = get_db_device_message(dev_id)
        local dev_dict = cjson.decode(device_object)
        dev_dict["DevType"] = dev_type
        dev_dict["DevId"] = dev_id
        local dev_info = g_sql_app.query_dev_info_tbl(dev_id)
        ngx.log(ngx.ERR,"################################################model= ",dev_info[1]["dev_model"])
        dev_dict["DevModel"] = dev_info[1]["dev_model"]

        local result = g_sql_app.query_dev_status_tbl(dev_id)
        if dev_dict["Attributes"] == nil then
            dev_dict["Attributes"] = {}
        end

        dev_dict["Attributes"]["Online"] = 1
        dev_dict["Attributes"]["SN"] = dev_info[1]["sn"]
        dev_dict["Attributes"]["AutoMode"] = result[1]["auto_mode"]

        table.insert(dev_list,dev_dict)
    end
    local gw, res = g_sql_app.query_dev_info_tbl(0)
    if gw[1] ~= nil then
        sn = gw[1]["sn"]
    else
        sn = ""
    end
    local online_object = g_message.creat_online_object(sn, dev_list)
    event_send_message(event_conf.url,cjson.encode(online_object))
end

-----------------------设备下线事件-----------------------
function event_report_M.thing_offline(devices)
    local dev_list = {}
    for key, value in pairs(devices) do
        local dev_id = value["DevId"]
        local dev_type = value["DevType"]
        --上报策略结束
        g_exec_rule.report_dev_end_status(dev_type, dev_id)
        --清除该设备时间策略运行状态
        g_exec_rule.clear_device_running(dev_type, dev_id)
        --清除设备默认状态标志
        g_rule_common.set_dev_dft_flag(dev_type, dev_id, 0)

        --上报属性
        local dev_info = g_sql_app.query_dev_info_tbl(dev_id)
        local attributes = {}
        attributes["Online"] = 0
        attributes["SN"] = dev_info[1]["sn"]
        value["Attributes"] = attributes
        table.insert(dev_list,value)
    end
    local gw, res = g_sql_app.query_dev_info_tbl(0)
    if gw[1] ~= nil then
        sn = gw[1]["sn"]
    else
        sn = ""
    end
    local offline_object = g_message.creat_offline_object(sn, dev_list)
    event_send_message(event_conf.url,cjson.encode(offline_object))
end

-----------------------------属性改变事件-----------------------
-----规则引擎触发
local function rule_engine_trigger(body)
    if body["Event"] == "StatusUpload" then
        local devices = body["Payload"]["Devices"]
        if devices == nil then
            return
        end
        for key, value in pairs(devices) do
            local request_body = {}
            request_body["Event"] = "StatusUpload"
            local rule_dev = {}
            rule_dev["DevType"] = value["DevType"]
            rule_dev["DevId"] = value["DevId"]
            local attributes = value["Attributes"]
            if attributes ~= nil then
                rule_dev["Attributes"] = attributes
            end

            local channels = value["Channels"]
            if channels ~= nil then
                for key1, value1 in pairs(channels) do
                    rule_dev["DevChannel"] = value1["Id"]
                    rule_dev["Attributes"] =value1["Attributes"]
                    request_body["Device"] = rule_dev
                    local request_str = cjson.encode(request_body)
                    ngx.log(ngx.ERR,"rule_engine_trigger: ",cjson.encode(body))
                    local result,status = g_micro.micro_post("RuleEngine",request_str)
                end
            end
        end
    elseif body["Event"] == "Alarm" then
        local request_str = cjson.encode(body)
        ngx.log(ngx.ERR,"rule_engine_trigger: ",cjson.encode(body))
        local result,status = g_micro.micro_post("RuleEngine",request_str)
    end
end

function event_report_M.attribute_change(body)
    local gw, res = g_sql_app.query_dev_info_tbl(0)
    if gw[1] ~= nil then
        body["GW"] = gw[1]["sn"]
    else
        body["GW"] = ""
    end
    event_send_message(event_conf.url,cjson.encode(body))
    rule_engine_trigger(body)
end

local function remove_table(base, remove)
    local new_table = {}
    for k, v in ipairs(base) do
        local find_key = false
        for rk, rv in ipairs(remove) do
            if rv == k then
                find_key = true
                break
            end
        end
        if not find_key then
            table.insert(new_table, v)
        end
    end
    return new_table
end

function event_report_M.method_respone_handle()
    if g_is_result_upload_timer_running == false then
        g_is_result_upload_timer_running = true
        --ngx.log(ngx.DEBUG,"method_respone_handle in, g_result_upload_msg_table size is ", table.maxn(g_result_upload_msg_table))
        local want_remove = {}
        for k, v in ipairs(g_result_upload_msg_table) do
            ngx.log(ngx.DEBUG,"for g_result_upload_msg_table size is ", table.maxn(g_result_upload_msg_table))
            local msg_id = v["MsgId"]
            ngx.log(ngx.DEBUG,"method_respone_handle start, MsgId: ",msg_id)
            if string.find(msg_id, "time_", 1) == nil then
                event_send_message(event_conf.url,cjson.encode(v))
                local payload = v["Payload"]
                local result = payload["Result"]
                if result == 0 then
                    local json_str = g_dev_status.get_real_cmd_data(msg_id)
                    if json_str~=nil then
                        g_dev_status.set_ack_cmd_data(msg_id)
                    end
                end
            else
                g_tstatus.update(v)
                local payload = v["Payload"]
                local result = payload["Result"]
                if result == 0 then
                    g_dev_status.set_ack_cmd_data(msg_id)
                end
            end
            g_dev_status.del_control_method(msg_id)
            table.insert(want_remove, k)
            ngx.log(ngx.DEBUG,"method_respone_handle end, MsgId: ",msg_id)
        end
        ---remove table what has been handle
        if next(want_remove)~= nil then
            while true do
                if not g_result_upload_msg_table_locker then
                    g_result_upload_msg_table_locker = true
                    g_result_upload_msg_table = remove_table(g_result_upload_msg_table, want_remove)
                    g_result_upload_msg_table_locker = false
                    break
                else
                    ngx.sleep(0.01)
                end
            end
        end
        g_is_result_upload_timer_running = false
        --ngx.log(ngx.DEBUG,"method_respone_handle out")
    end
end

-------------------------操作回复事件---------------------------------
function event_report_M.method_respone(body)
    local gw, res = g_sql_app.query_dev_info_tbl(0)
    if gw[1] ~= nil then
        body["GW"] = gw[1]["sn"]
    else
        body["GW"] = ""
    end
    while true do
        if not g_result_upload_msg_table_locker then
            g_result_upload_msg_table_locker = true
            ngx.log(ngx.DEBUG,"method_respone g_result_upload_msg_table size befor insert is ", table.maxn(g_result_upload_msg_table))
            table.insert(g_result_upload_msg_table, body)
            ngx.log(ngx.DEBUG,"method_respone g_result_upload_msg_table size after insert is ", table.maxn(g_result_upload_msg_table))
            g_result_upload_msg_table_locker = false
            break
        else
            ngx.sleep(0.01)
        end
    end
end

--------------------------联动事件------------------------------------
--联动开始
local function linkage_start(body)
    --获取方法模式，设置redis
    for key,dev_id in pairs(body) do
        local update_json = {}
        update_json["linkage_rule"] = 1
        update_json["online"] = 1
        g_sql_app.update_dev_status_tbl(dev_id,update_json)
        g_linkage.linkage_start_stop_rule(nil,dev_id,1)
        --设备的时间策略失效
    end
end

--命令执行,恢复状态
local function cmd_post(dev_cmd_list)
    for k,cmd_obj in pairs(dev_cmd_list) do
        cmd_obj["MsgId"] = nil
        cmd_obj["TimeStamp"] = nil
        if (cmd_obj["Method"] ~= "Reboot") and (cmd_obj["Method"] ~= "ScreenShot") then
        --if string.find(cmd_obj["Method"], "Reboot", 1) == nil or string.find(cmd_obj["Method"], "ScreenShot", 1) == nil then
            local json_str = cjson.encode(cmd_obj)
            local res,ok = g_micro.micro_post(cmd_obj["DevType"],json_str)
        end
    end
end

--根据命令时间戳排序
local function time_sort(a,b)
    return tonumber(a.TimeStamp)< tonumber(b.TimeStamp)
end

--联动结束
local ignore_restore_method_table = {"DelProgram", "AddProgram", "Reboot", "ScreenShot"}

local function linkage_end(body)
    for key,dev_id in pairs(body) do
        local update_json = {}
        update_json["linkage_rule"] = 0
        update_json["online"] = 1
        g_sql_app.update_dev_status_tbl(dev_id,update_json)
        local dev_cmd_list = {}
        --匹配该设备id所有方法
        local key_str = string.format("%d-*",dev_id)
        local keys = g_dev_status.get_keys(key_str)
        for index,value in ipairs(keys) do
            local json_str = g_dev_status.get_real_cmd_data(value)
            local cmd_obj = cjson.decode(json_str)
            local method = cmd_obj["Method"]
            local is_ignore_method = false
            for k,v in ipairs(ignore_restore_method_table) do
                if v == method then
                    is_ignore_method = true
                    break
                end
            end
            if is_ignore_method == false then
                table.insert(dev_cmd_list,cmd_obj)
            end
        end
        --所有方法根据时间戳排序恢复状态
        local auto_mode = false
        local res,err = g_sql_app.query_dev_status_tbl(dev_id)
        if res then
            for key, value in ipairs(res) do
                if 1 == value.auto_mode then
                    auto_mode = true
                end
            end
        end
        --如果设备为自动模式，联动恢复时不需要从redis里面恢复，直接调用定时策略恢复即可
        if auto_mode == false then
            table.sort(dev_cmd_list,time_sort)
            ngx.log(ngx.INFO,"linkage_end restore to manual, dev_id: ",dev_id)
            cmd_post(dev_cmd_list)
        else
        --恢复模式
            ngx.log(ngx.INFO,"linkage_end linkage_start_stop_rule, dev_id: ",dev_id)
            g_linkage.linkage_start_stop_rule(nil,dev_id,0)
        end
    end
end

function event_report_M.linkage_event(body)
    local playload = body["Payload"]
    local status = playload["Status"]
    if status == "Start" then
        local out = playload["Out"]
        linkage_start(out)
    elseif status == "End" then
        local out = playload["Out"]
        linkage_end(out)
    end
    playload["Out"] = nil
    body["Payload"] = playload
    local gw, res = g_sql_app.query_dev_info_tbl(0)
    if gw[1] ~= nil then
        body["GW"] = gw[1]["sn"]
    else
        body["GW"] = ""
    end
    event_send_message(event_conf.url,cjson.encode(body))
end


--------------------------平台状态改变------------------------------------
local function creat_device_message(dev_type,dev_id,sn,dev_model,methods)
    local dev_dict = {}
    local res,err = g_sql_app.query_dev_status_tbl(dev_id)
    if res then
        for key, value in ipairs(res) do
            dev_dict = cjson.decode(value.attribute)
            dev_dict["DevType"] = dev_type
            dev_dict["DevId"] = dev_id
            dev_dict["DevModel"] = dev_model
            local attributes = {}
            for k, v in pairs(dev_dict) do
                if k == "Attributes" then
                    attributes = dev_dict["Attributes"]
                    break
                end
            end
            attributes["Online"] = value.online
            attributes["AutoMode"] = value.auto_mode
            attributes["SN"] = sn
            dev_dict["Attributes"] = attributes
        end
    else
        return nil
    end
    return dev_dict
end


function event_report_M.platform_online_event(body)
    if body["Status"] == 1 then
        --全量上报
        local dev_list = {}
        local gw = {}
        local res,err = g_sql_app.query_all_dev_info_tbl()
        for key,device in pairs(res) do
            if device.dev_id > 0 then
                local dev_dict = creat_device_message(device.dev_type,device.dev_id,device.sn,device.dev_model,device.ability_method)
                if dev_dict ~= nil then
                    table.insert(dev_list,dev_dict)
                end
            else
                gw = device 
            end
        end
        local gw_message =  g_sql_app.query_dev_status_tbl(0)
        if gw_message[1] ~= nil then
            local attributes1 = gw_message[1]["attribute"]
            local attributes_table = cjson.decode(attributes1)
            local Attributes = attributes_table["Attributes"]
            Attributes["Online"] = 1
            Attributes["SN"] = gw["sn"]
            local Playload = {}
            Playload["Attributes"] = Attributes
            Playload["Methods"] = attributes_table["Methods"]
            Playload["Devices"] = dev_list
            local message = {}
            message["Token"] = "7GBox"
            message["Event"] = "StatusUpload"
            message["GW"] = gw["sn"]
            message["Payload"] = Playload
            event_send_message(event_conf.url,cjson.encode(message))
        end
        
    elseif body["Status"] == 0 then
    end
end

function event_report_M.platform_heart_event()
    local message = {}
    message["Token"] = "7GBOX"
    message["Event"] = "Heartbeat"
    local gw, res = g_sql_app.query_dev_info_tbl(0)
    if gw[1] ~= nil then
        message["GW"] = gw[1]["sn"]
    else
        message["GW"] = ""
    end
    event_send_message(event_conf.url,cjson.encode(message))
    
end

-------------------------时间策略执行状态------------------------------
function event_report_M.transmit_do_nothing(body)
    event_send_message(event_conf.url,cjson.encode(body))
end

return event_report_M

