local m_dev_dft = {}

--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")


local function set_common_dft(dev_type, dev_id, channel, req_data)
    req_data["dev_type"] = dev_type
    req_data["dev_id"] = dev_id
    req_data["dev_channel"] = channel

    local rt = g_rule_common.exec_http_request(req_data)
    return rt
end

local function set_lamp_dft(dev_type, dev_id, channel)
    local req_data = {}

    req_data["method"] = "SetOnOff"
    local param = {}
    param["OnOff"] = 0
    req_data["rule_param"] = cjson.encode(param)

    local rt = set_common_dft(dev_type, dev_id, channel, req_data)
    return rt
end

local function set_infoscreen_dft(dev_type, dev_id, channel)
    local req_data = {}

    req_data["method"] = "SetOnOff"
    local param = {}
    param["OnOff"] = 0
    req_data["rule_param"] = cjson.encode(param)

    local rt = set_common_dft(dev_type, dev_id, channel, req_data)
    return rt
end

local function set_ipc_onvif_dft(dev_type, dev_id, channel)
    return true
end

local function set_speaker_dft(dev_type, dev_id, channel)
    local req_data = {}

    req_data["method"] = "StopProgram"
    local param = {}
    req_data["rule_param"] = cjson.encode(param)

    local rt = set_common_dft(dev_type, dev_id, channel, req_data)
    return rt
end

function m_dev_dft.set_channel_dft(dev_type, dev_id, channel)
    --检测微服务是否在线
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "online")
    if rt == false then
        ngx.log(ngx.NOTICE,"srv "..dev_type.."-"..dev_id.." is offline, can not set default! ")
        return "srv is offline, can not set default! ", false
    end
    --检测联动是否在执行
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "linkage")
    if rt == true then
        ngx.log(ngx.NOTICE,dev_type.."-"..dev_id.." linkage rule running, can not set default! ")
        return "linkage rule running, can not set default! ", false
    end
    --检测是否手动模式
    local rt = g_rule_common.check_dev_status(dev_type, dev_id, "cmd")
    if rt == true then
        ngx.log(ngx.NOTICE,dev_type.."-"..dev_id.." cmd running, can not set default! ")
        return "cmd running, can not set default! ", false
    end

    ngx.log(ngx.INFO,"set "..dev_type.."-"..dev_id.." to default status")
    if dev_type == "Lamp" then
        set_lamp_dft(dev_type, dev_id, channel)
    elseif dev_type == "InfoScreen" then
        set_infoscreen_dft(dev_type, dev_id, channel)
    elseif dev_type == "IPC-Onvif" then
        set_ipc_onvif_dft(dev_type, dev_id, channel)
    elseif dev_type == "Speaker" then
        set_speaker_dft(dev_type, dev_id, channel)
    else
        ngx.log(ngx.ERR,"DevType error")
        return "DevType error", false 
    end
    return "", true
end

function m_dev_dft.set_dev_dft(dev_type, dev_id)
    if dev_type == "AI" or
        dev_type == "GW" or
        dev_type == "Configure"
    then
        return "", true
    end

    local sql_str = string.format("select * from run_rule_tbl where dev_type=\'%s\' and dev_id=%d", dev_type, dev_id)
    local res,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res,err)
        return err, false
    end
    if next(res) == nil then
        --ngx.log(ngx.INFO,"set "..dev_type.."-"..dev_id.." to default status")
        m_dev_dft.set_channel_dft(dev_type, dev_id, 1)  --如何获取全部channel
    end
    return "", true
end

function m_dev_dft.set_all_dev_dft()
    local sql_str = string.format("select * from dev_info_tbl")
    local devices,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", devices,err)
        return err, false
    end
    if next(devices) ~= nil then
        for i,device in ipairs(devices) do
            --ngx.log(ngx.INFO,"check "..device["dev_type"].."-"..device["dev_id"].." is/not default status")
            m_dev_dft.set_dev_dft(device["dev_type"], device["dev_id"])
        end
    end
end

return m_dev_dft