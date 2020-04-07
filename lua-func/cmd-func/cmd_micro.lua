--cmd micro
local cmd_micro_M = {version='v1.0.1'}

local g_sql_app = require("common.sql.g_orm_info_M")
local g_http = require("common.http.myhttp_M")
local cjson = require("cjson")
local g_dev_status = require("dev-status-func.dev_status")

----------获取微服务url地址------------
local function get_url_suffix(request_body)
    local body = cjson.decode(request_body)
    if body["Event"] == "StatusUpload" then
        return "event"
    elseif body["Event"] == "Alarm" then
        return "event"
    elseif body["Method"] == "CancleLinkageRule" then
        return "event"
    elseif body["Payload"] ~= nil and body["Payload"]["RuleType"] == "LinkageRule" then
        return "rule"
    else
        --设备微服务 命令存到redis,等待微服务执行结果确认
        g_dev_status.set_temp_cmd_data(request_body)
        return "ioctl"
    end
end

function cmd_micro_M.get_mico_url(svr_type,request_body)
    local res, err = g_sql_app.query_micro_svr_tbl(svr_type)
    if res then
        for key, value in ipairs(res) do
            local url_prefix = string.gsub(value["url_prefix"], "%s+", "")
            local online = value["online"]
            local suffix = get_url_suffix(request_body)
            if svr_type == "RuleEngine" then
                local url = string.format('%s/%s',url_prefix,suffix)
                return url,online
            else
                local url = string.format('%s/%s',url_prefix,suffix)
                return url,online
            end
        end
    else
        ngx.log(ngx.ERR,"micro server url is not exit svr= ",svr_type)
    end
	return nil,0
end

---------微服务调用----------------
local function micro_cmd_exec(svr_type,request_body, method)
    local url,online = cmd_micro_M.get_mico_url(svr_type,request_body)
    if  online == 1 then
        g_http.init()
        ngx.log(ngx.ERR,"##method: ",method)
        ngx.log(ngx.ERR,"##url: ",url)
        ngx.log(ngx.INFO, "##body: ", request_body)
        local res,status = g_http.request_url(url,method,request_body)
        g_http.uninit()
        if status == true then
            ngx.log(ngx.INFO, "micro_cmd_exec success\n")
            return res,true
        else
            ngx.log(ngx.ERR, "micro_cmd_exec failed\n")
            local json_str = '{\n\"Errcode\":400,\n \"Msg\":\"fail",\n \"Payload\":{}\n}'
            return json_str,false
        end
    else
        local json_str = '{\n\"Errcode\":400,\n \"msg\":\"Server is offline",\n \"Payload\":{}\n}'
        ngx.log(ngx.ERR,"micro server is offline!")
        return json_str,false
    end
end


function cmd_micro_M.micro_post(svr_type,request_body)
    local res,ok = micro_cmd_exec(svr_type,request_body, "POST")
    ngx.log(ngx.INFO, "cmd_micro_M.micro_post return: ",res)
    return res,ok
end

function cmd_micro_M.micro_get(svr_type,request_body)
    local res,ok = micro_cmd_exec(svr_type,request_body, "GET")
    return res,ok
end

function cmd_micro_M.micro_delete(svr_type,request_body)
    local res,ok = micro_cmd_exec(svr_type,request_body, "DELETE")
    return res,ok
end

function cmd_micro_M.micro_put(svr_type,request_body)
    local res,ok = micro_cmd_exec(svr_type,request_body, "PUT")
    return res,ok
end
return cmd_micro_M