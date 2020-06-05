local m_dev_dft = {}

--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_tstatus = require("alone-func.time_rule_status")
local g_report_event = require("alone-func.rule_report_event")

local function get_dft_non_exec_start_time(dev_type, dev_id, channel)
    local sql_str = string.format("select * from run_rule_tbl where (dev_type=\'%s\' and dev_id=%d and dev_channel=%d and start_date<=current_date and current_date<=end_date and end_time <= current_time) order by end_time DESC limit 1", dev_type, dev_id, channel)
    local res,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res,err)
        return false
    end
    if next(res) == nil then
        --当前时间之前没有结束时间点，返回当前时间
        return os.date("%H:%M:%S")      --os.date("%Y-%m-%d %H:%M:%S")
    end
    --ngx.log(ngx.INFO,"===========1111: ", cjson.encode(res[1]))
    return res[1]["end_time"]
end

local function get_dft_start_time(dev_type, dev_id, channel)
    local sql_str = string.format("select * from run_rule_tbl where (dev_type=\'%s\' and dev_id=%d and dev_channel=%d)", dev_type, dev_id, channel)
    local res,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res,err)
        return false
    end
    if next(res) == nil then
        --当前设备没有时间策略
        return "00:00:00"
    else
        local s_time = get_dft_non_exec_start_time(dev_type, dev_id, channel)
        return s_time
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

    ngx.log(ngx.DEBUG,"default rule: ", cjson.encode(data))
    return data
end

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
    while wait_time < 30 do
        ngx.sleep(0.1)
        ngx.log(ngx.DEBUG,"check rule result-upload: ", req_data["rule_uuid"].."  "..http_param_table["MsgId"])
        local msrvcode, desp = g_tstatus.check_result_upload(http_param_table["MsgId"])
        ngx.log(ngx.DEBUG,"check "..http_param_table["MsgId"]..": ", msrvcode, desp)

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
        wait_time = wait_time + 1
    end
    ngx.log(ngx.DEBUG,"exec ", req_data["rule_uuid"].."  "..http_param_table["MsgId"].." complete")

    if wait_time >= 30 then
        --超时
        rt_value = false
        g_report_event.report_rule_exec_status(req_data, "Start", 1, 4, "Timeout")
    end

    --删除redis
    g_tstatus.del(http_param_table["MsgId"])

    return rt_value
end

function m_dev_dft.set_channel_dft(dev_type, dev_id, channel)
    --检测微服务是否在线
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "online")
    if rt == false then
        ngx.log(ngx.NOTICE,"srv "..dev_type.."-"..dev_id.." is offline, can not set default! ")
        return nil
    end
    --检测联动是否在执行
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "linkage")
    if rt == true then
        ngx.log(ngx.NOTICE,dev_type.."-"..dev_id.." linkage rule running, can not set default! ")
        return nil
    end
    --检测是否手动模式
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "cmd")
    if rt == true then
        ngx.log(ngx.NOTICE,dev_type.."-"..dev_id.." cmd running, can not set default! ")
        return nil
    end

    --检测是否已设置默认
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "default")
    if rt == true then
        ngx.log(ngx.DEBUG,dev_type.."-"..dev_id.." device is default already! ")
        return nil
    end

    ngx.log(ngx.INFO,"set "..dev_type.."-"..dev_id.." to default status")
    
    --请求微服务
    local dft_rule = m_dev_dft.encode_device_dft(dev_type, dev_id, channel)
    local rt_value = exec_dft_request(dft_rule)

    --设置设备已是默认状态
    if rt_value == true then
        g_rule_common.set_dev_dft_flag(dev_type, dev_id, 1)
    end

    return rt_value
end

function m_dev_dft.set_dev_dft(dev_type, dev_id)
    local dev_group = {g_rule_common.lamp_type, g_rule_common.screen_type, g_rule_common.speaker_type}
    local include = g_rule_common.is_include(dev_type, dev_group)
    if include == false then
        return true
    end

    local sql_str = string.format("select * from run_rule_tbl where dev_type=\'%s\' and dev_id=%d", dev_type, dev_id)
    local res,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res,err)
        return nil
    end

    local rt_value
    if next(res) == nil then
        --ngx.log(ngx.INFO,"set "..dev_type.."-"..dev_id.." to default status")
        rt_value = m_dev_dft.set_channel_dft(dev_type, dev_id, 1)  --如何获取全部channel
    end
    return rt_value
end

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
    if include then
        return false
    end
    return true
end

return m_dev_dft