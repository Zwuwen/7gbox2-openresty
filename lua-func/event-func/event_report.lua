--http module
local event_report_M = {version='v1.0.1'}

local g_http = require("common.http.myhttp_M")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_message = require("event-func.message_M")
local event_conf = require("conf.event_conf")
local g_micro = require("cmd-func.cmd_micro")
local g_dev_status = require("dev-status-func.dev_status")

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
        for key, value in ipairs(res) do
            local attribute = value["attribute"]
            return attribute
        end
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
        local device_object = get_db_device_message(dev_id)
        local dev_dict = cjson.decode(device_object)
        dev_dict["DevType"] = dev_type
        dev_dict["DevId"] = dev_id
        local attributes = {}
        attributes["Online"] = 1
        dev_dict["Attributes"] = attributes
        table.insert(dev_list,dev_dict)
    end
    local online_object = g_message.creat_online_object("00E04C360350",dev_list)
    event_send_message(event_conf.url,cjson.encode(online_object))
end

-----------------------设备下线事件-----------------------
function event_report_M.thing_offline(devices)
    local dev_list = {}
    for key, value in pairs(devices) do
        local attributes = {}
        attributes["Online"] = 0
        value["Attributes"] = attributes
        table.insert(dev_list,value)
    end
    local offline_object = g_message.creat_offline_object("00E04C360350",dev_list)
    event_send_message(event_conf.url,cjson.encode(offline_object))
end

-----------------------------属性改变事件-----------------------
-----规则引擎触发
local function rule_engine_trigger(body)
    local devices = body["Devices"]
    for key, value in pairs(devices) do
        local request_body = {}
        request_body["Event"] = "StatusUpload"
        local rule_dev = {}
        rule_dev["DevType"] = value["DevType"]
        rule_dev["DevId"] = value["DevId"]
        local channels = value["Channels"]
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

function event_report_M.attribute_change(body)
    body["GW"] = "00E04C360350"
    event_send_message(event_conf.url,cjson.encode(body))
    rule_engine_trigger(body)
end

-------------------------操作回复事件---------------------------------
function event_report_M.method_respone(body)
    body["GW"] = "1010-10000"
    local msg_id = body["MsgId"]
    ngx.log(ngx.ERR,"###method_respone MsgId: ",msg_id)
    if string.find(msg_id, "time_", 1) == nil then
        event_send_message(event_conf.url,cjson.encode(body))
        g_dev_status.set_ack_cmd_data(msg_id)
    end
end

--------------------------联动事件------------------------------------
--联动开始
local function linkage_start(body)
    --获取方法模式，设置redis
    for key,dev_id in pairs(body) do
        dev_id = 1
        --设备的时间策略失效
    end
end

--命令执行,恢复状态
local function cmd_post(dev_cmd_list)
    for k,cmd_obj in pairs(dev_cmd_list) do
        cmd_obj["MsgId"] = nil
        cmd_obj["TimeStamp"] = nil
        json_str = cjson.encode(cmd_obj)
        local res,ok = g_micro.micro_post(cmd_obj["DevType"],json_str)
    end
end

--根据命令时间戳排序
local function time_sort(a,b)
    return tonumber(a.TimeStamp)< tonumber(b.TimeStamp)
end

--联动结束
local function linkage_end(body)
    for key,dev_id in pairs(body) do
        local dev_cmd_list = {}
        --匹配该设备id所有方法
        local key_str = string.format("%d-*",dev_id)
        local keys = g_dev_status.get_keys(key_str)
        for index,value in ipairs(keys) do
            local json_str = g_dev_status.get_real_cmd_data(value)
            local cmd_obj = cjson.decode(json_str)
            table.insert(dev_cmd_list,cmd_obj)
        end
        --所有方法根据时间戳排序恢复状态
        table.sort(dev_cmd_list,time_sort)
        cmd_post(dev_cmd_list)
        --恢复模式
    end
end

function event_report_M.linkage_event(body)
    local playload = body["Payload"]
    local status = playload["Status"]
    if status == 1 then
        local out = playload["Out"]
        linkage_start(out)
    elseif status == 2 then
        local out = playload["Out"]
        linkage_end(out)
    end
    playload["Out"] = nil
    body["Payload"] = playload
    event_send_message(event_conf.url,cjson.encode(body))
end


--------------------------平台状态改变------------------------------------
local function creat_device_message(dev_type,dev_id,methods)
    local dev_dict = {}
    local res,err = g_sql_app.query_dev_status_tbl(dev_id)
    if res then
        for key, value in ipairs(res) do
            dev_dict = cjson.decode(value.attribute)
            dev_dict["DevType"] = dev_type
            dev_dict["DevId"] = dev_id
            local attributes = {}
            attributes["Online"] = value.online
            dev_dict["Attributes"] = attributes
        end
    else
        dev_dict["DevType"] = dev_type
        dev_dict["DevId"] = dev_id
        local attributes = {}
        attributes["Online"] = 0
        dev_dict["Attributes"] = attributes
    end
    return dev_dict
end

local function get_gw_message()
    local dev_dict = {}
    local res,err = g_sql_app.query_dev_status_tbl(0)
    if res then
        for key, value in ipairs(res) do
            dev_dict = cjson.decode(value.attribute)
        end
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
                local dev_dict = creat_device_message(device.dev_type,device.dev_id,device.ability_method)
                table.insert(dev_list,dev_dict)
            else
                gw = device    
            end
        end
        local gw_message = get_gw_message()
        local Attributes = gw_message["Attributes"]
        Attributes["Online"] = 1
        Attributes["SN"] = gw.sn
        local Playload = {}
        Playload["Attributes"] = Attributes
        Playload["Methods"] = gw_message["Methods"]
        Playload["Devices"] = dev_list
        local message = {}
        message["Token"] = "7GBox"
        message["Event"] = "StatusUpload"
        message["GW"] = gw.sn
        message["Payload"] = Playload
        event_send_message(event_conf.url,cjson.encode(message))
    elseif body["Status"] == 0 then
    end
end

return event_report_M

