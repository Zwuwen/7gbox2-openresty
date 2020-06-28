local m_dev_dft = {}

--load module
local g_rule_common = require("rule-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_tstatus = require("rule-func.time_rule_status")
local g_report_event = require("rule-func.rule_report_event")

--正在设置默认
local dft_run = 1
--设置默认停止
local dft_stop = 0

local rule_dft_objs = {}

local function insert_dft_table(dev_type, dev_id, channel)
    local rule_dft_obj = {}
    rule_dft_obj["dev_type"] = dev_type
    rule_dft_obj["dev_id"] = dev_id
    rule_dft_obj["dev_channel"] = channel
    rule_dft_obj["status"] = dft_run
    table.insert(rule_dft_objs, rule_dft_obj)
end

local function delete_dft_table(dev_type, dev_id, channel)
    for i,rule_dft_obj in ipairs(rule_dft_objs) do
        if (rule_dft_obj["dev_type"] == dev_type) and
            (rule_dft_obj["dev_id"] == dev_id) --and
            --(rule_dft_obj["dev_channel"] == channel)
        then
            table.remove(rule_dft_objs, i)
        end
    end
end

--获取设备策略运行状态
--rt: true  -- idle
--rt: false -- 正在设置默认
function m_dev_dft.get_device_dft_idle_status(dev_type, dev_id, channel)
    if next(rule_dft_objs) == nil then
        return true
    end
    --ngx.log(ngx.DEBUG,"check rule_dft_objs cnt: ", #rule_dft_objs)
    for i,rule_dft_obj in ipairs(rule_dft_objs) do
        if (rule_dft_obj["dev_type"] == dev_type) and
            (rule_dft_obj["dev_id"] == dev_id) --and
            --(rule_dft_obj["dev_channel"] == channel)
        then
            if (rule_dft_obj["status"] == dft_run) or     --正在下发
                (rule_dft_obj["status"] == dft_stop)      --正在取消，取消后就已删除查不到
            then
                ngx.log(ngx.DEBUG, dev_type.."-"..dev_id.."-"..channel.." has default executeing")
                return false
            end
        end
    end
    ngx.log(ngx.DEBUG, dev_type.."-"..dev_id.."-"..channel.." has no default executeing")
    return true
end

function m_dev_dft.get_device_dft_cancel_status(dev_type, dev_id, channel)
    if next(rule_dft_objs) == nil then
        return true
    end
    --ngx.log(ngx.DEBUG,"check rule_dft_objs cnt: ", #rule_dft_objs)
    for i,rule_dft_obj in ipairs(rule_dft_objs) do
        if (rule_dft_obj["dev_type"] == dev_type) and
            (rule_dft_obj["dev_id"] == dev_id) --and
            --(rule_dft_obj["dev_channel"] == channel)
        then
            if (rule_dft_obj["status"] == dft_stop) then
                ngx.log(ngx.DEBUG, dev_type.."-"..dev_id.."-"..channel.." should cancel default")
                return true
            end
        end
    end
    
    return false
end

--停止设置默认执行
function m_dev_dft.stop_device_dft_exec(dev_type, dev_id, channel)
    if next(rule_dft_objs) == nil then
        return
    end
    for i,rule_dft_obj in ipairs(rule_dft_objs) do
        if (rule_dft_obj["dev_type"] == dev_type) and
            (rule_dft_obj["dev_id"] == dev_id) --and
            --(rule_dft_obj["dev_channel"] == channel)
        then
            ngx.log(ngx.DEBUG, "set "..dev_type.."-"..dev_id.."-"..channel.." default cancel")
            rule_dft_obj["status"] = dft_stop
        end
    end 
end

local function encode_common_dft(dev_type, dev_id, channel, req_data)
    req_data["rule_uuid"] = dev_type.."_"..tostring(dev_id).."_default"
    req_data["dev_type"] = dev_type
    req_data["dev_id"] = dev_id
    req_data["dev_channel"] = channel

    local actions = {}
    local action = {}
    action["Method"] = req_data["method"]
    action["RuleParam"] = cjson.decode(req_data["rule_param"])
    table.insert (actions, action)
    req_data["actions"] = cjson.encode(actions)
end

local function encode_lamp_dft(dev_type, dev_id, channel)
    local req_data = {}

    req_data["method"] = "SetOnOff"
    local param = {}
    param["OnOff"] = 0
    req_data["rule_param"] = cjson.encode(param)

    encode_common_dft(dev_type, dev_id, channel, req_data)
    return req_data
end

local function encode_infoscreen_dft(dev_type, dev_id, channel)
    local req_data = {}

    req_data["method"] = "SetOnOff"
    local param = {}
    param["OnOff"] = 0
    req_data["rule_param"] = cjson.encode(param)

    encode_common_dft(dev_type, dev_id, channel, req_data)
    return req_data
end

local function encode_ipc_onvif_dft(dev_type, dev_id, channel)
    return nil
end

local function encode_speaker_dft(dev_type, dev_id, channel)
    local req_data = {}

    req_data["method"] = "StopProgram"
    local param = {}
    req_data["rule_param"] = cjson.encode(param)

    encode_common_dft(dev_type, dev_id, channel, req_data)
    return req_data
end

--生成默认策略数据
function m_dev_dft.encode_device_dft(dev_type, dev_id, channel)
    local data
    if dev_type == g_rule_common.lamp_type then
        data = encode_lamp_dft(dev_type, dev_id, channel)
    elseif dev_type == g_rule_common.screen_type then
        data = encode_infoscreen_dft(dev_type, dev_id, channel)
    elseif dev_type == g_rule_common.ipc_onvif_type then
        data = encode_ipc_onvif_dft(dev_type, dev_id, channel)
    elseif dev_type == g_rule_common.speaker_type then
        data = encode_speaker_dft(dev_type, dev_id, channel)
    else
        ngx.log(ngx.ERR,"DevType error")
        return nil
    end

    --ngx.log(ngx.DEBUG,"default rule: ", cjson.encode(data))
    return data
end

--执行默认状态
--rt true: 设置成功
--rt false: 设置失败
local function exec_dft_request(req_data)
    local rt_value = false
    --生成微服务报文
    local http_param_table = g_rule_common.encode_http_downstream_param(req_data)
    --请求微服务
    local rt = g_rule_common.exec_http_request(http_param_table)
    if rt == false then
        ngx.log(ngx.ERR,"request http fail ")
        return false
    end

    --插入redis
    g_tstatus.add(http_param_table)

    --等待ResultUpload
    local wait_time = 0
    while wait_time < 200 do
        ngx.sleep(0.1)
        --ngx.log(ngx.DEBUG,"check rule result-upload: ", req_data["rule_uuid"].."  "..http_param_table["MsgId"])
        local msrvcode, desp = g_tstatus.check_result_upload(http_param_table["MsgId"])
        --ngx.log(ngx.DEBUG,"check "..http_param_table["MsgId"]..": ", msrvcode, desp)
        --msrvcode = 1  --测试用

        if msrvcode ~= nil then
            --收到，返回结果
            if msrvcode == 0 then
                rt_value = true
                --上报设置成功状态
                g_report_event.report_rule_exec_status(req_data, "Start", 1, 0, "Success")
            else
                rt_value = false
                --上报设置失败状态
                g_report_event.report_rule_exec_status(req_data, "Start", 1, msrvcode, desp)
            end
            break
        end

        --检查是否取消设置默认
        local cancel = m_dev_dft.get_device_dft_cancel_status(req_data["dev_type"], req_data["dev_id"], req_data["dev_channel"])
        if cancel == true then
            ngx.log(ngx.DEBUG,"cancel "..req_data["dev_type"].."-"..req_data["dev_id"].."-"..req_data["dev_channel"].." default")
            rt_value = nil
            break
        end

        wait_time = wait_time + 1
    end
    --ngx.log(ngx.DEBUG,"exec ", req_data["rule_uuid"].."  "..http_param_table["MsgId"].." complete")

    if wait_time >= 200 then
        --超时
        ngx.log(ngx.ERR,"set default timeout")
        rt_value = false
        g_report_event.report_rule_exec_status(req_data, "Start", 1, 4, "Timeout")
    end

    --删除redis
    g_tstatus.del(http_param_table["MsgId"])

    return rt_value
end

--rt true: 设置成功
--rt false: 设置失败
local function set_channel_dft(dev_type, dev_id, channel)    
    ngx.log(ngx.INFO,"set "..dev_type.."-"..dev_id.."-"..channel.." to default status")

    local dft_rule = m_dev_dft.encode_device_dft(dev_type, dev_id, channel)
    if dft_rule == nil then
        ngx.log(ngx.ERR,"default rule nil")
        return false
    end

    insert_dft_table(dev_type, dev_id, channel)
    local rt_value = exec_dft_request(dft_rule)
    delete_dft_table(dev_type, dev_id, channel)

    --设置设备默认状态标志
    if rt_value == true then
        g_rule_common.set_dev_dft_flag(dev_type, dev_id, 1)
    end

    return rt_value
end

--rt true: 设置成功或不需要设置
--rt false: 设置失败
local function check_and_set_channel_dft(dev_type, dev_id, channel)
    --查看是否有可执行策略
    local ruletable, err = g_sql_app.query_rule_tbl_by_channel(dev_type, dev_id, channel)
    if err then
        ngx.log(ngx.ERR,"postgresql io err: ",err)
        return nil
    end

    if next(ruletable) == nil then
        --设备设置了时间策略，但是当前时间没有可执行策略，设为默认状态
        ngx.log(ngx.DEBUG,dev_type.."-"..dev_id.." has no rules to exec, set default")
        local set_dft_status = set_channel_dft(dev_type, dev_id, channel)
        return set_dft_status
    end
    --ngx.log(ngx.DEBUG,dev_type.."-"..dev_id.." rules running, do not set default")
    return true
end

--rt true: 设置成功或不需要设置
--rt false: 设置失败
function m_dev_dft.set_dev_dft(dev_type, dev_id)
    --屏蔽没有策略的设备
    local dev_group = {g_rule_common.lamp_type, g_rule_common.screen_type, g_rule_common.speaker_type}
    local include = g_rule_common.is_include(dev_type, dev_group)
    if include == false then
        return true
    end

    --检测微服务是否在线
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "online")
    if rt == false then
        ngx.log(ngx.NOTICE,"srv "..dev_type.."-"..dev_id.." is offline, can not set default! ")
        --上线时可能执行，不需要反错重试
        return true
    end
    --检测联动是否在执行
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "linkage")
    if rt == true then
        ngx.log(ngx.NOTICE,dev_type.."-"..dev_id.." linkage rule running, can not set default! ")
        --该设备当前不能设置默认，忽略本次设置
        return true
    end
    --检测是否手动模式
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "cmd")
    if rt == true then
        ngx.log(ngx.NOTICE,dev_type.."-"..dev_id.." cmd running, can not set default! ")
        --该设备当前不能设置默认，忽略本次设置
        return true
    end
    --检测是否已设置默认
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "default")
    if rt == true then
        ngx.log(ngx.DEBUG,dev_type.."-"..dev_id.." device is default already! ")
        --已经是默认状态
        return true
    end

    --查看设备是否配置了策略
    local sql_str = string.format("select * from run_rule_tbl where dev_type=\'%s\' and dev_id=%d", dev_type, dev_id)
    local devices,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR,"postgresql io err: ",err)
        return nil  --暂不重试
    end

    --获取设备channel数
    local channel_cnt = g_rule_common.get_dev_channel_cnt(dev_type, dev_id)
    if channel_cnt == nil then
        ngx.log(ngx.ERR,"query dev_channel cnt err")
        return nil
    end

    local rt_value_table = {}
    if next(devices) == nil then
        --设备无策略
        ngx.log(ngx.DEBUG,dev_type.."-"..dev_id.." has no rules")
        for i=1,channel_cnt do
            local rt_value = set_channel_dft(dev_type, dev_id, i)
            table.insert(rt_value_table, rt_value)
        end
    else
        --设备有策略
        --ngx.log(ngx.DEBUG,dev_type.."-"..dev_id.." has rules")
        for i=1,channel_cnt do
            local rt_value = check_and_set_channel_dft(dev_type, dev_id, i)
            table.insert(rt_value_table, rt_value)
        end
    end
    
    local include = g_rule_common.is_include(false, rt_value_table)
    if include == true then
        --有设置失败的
        ngx.log(ngx.ERR,dev_type.."-"..dev_id.." set default fail")
        return false
    end
    return true
end

--返回值同set_dev_dft
function m_dev_dft.set_all_dev_dft()
    local sql_str = string.format("select * from dev_info_tbl")
    local devices,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", devices,err)
        return nil
    end

    local rt_value_table = {}
    if next(devices) ~= nil then
        for i,device in ipairs(devices) do
            --ngx.log(ngx.INFO,"check "..device["dev_type"].."-"..device["dev_id"].." is/not default status")
            local rt_value = m_dev_dft.set_dev_dft(device["dev_type"], device["dev_id"])
            table.insert(rt_value_table, rt_value)
        end
    end

    local include = g_rule_common.is_include(false, rt_value_table)
    if include == true then
        --有设置失败的
        ngx.log(ngx.ERR,"set all default has fail, need retry")
        return false
    end
    return true
end

return m_dev_dft