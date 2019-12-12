--eventfunction
--restful parsing parameters

--const define

--load module
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_event_report = require("event-func.event_report")


------------------------------------event handle function api-----------------------------------------
local function get_method()
    
end

local function put_method()
    
end

local function delete_method()
    
end

-------------post method---------
local function post_method()
    ngx.req.read_body()
		local request_body = ngx.req.get_body_data()
    ngx.log(ngx.ERR,"micro post event: ",request_body)
    local body = cjson.decode(request_body)
    if body["Event"] == "ThingsOnline" then
        --设备上线事件
        g_event_report.thing_online(body["Devices"])
    elseif body["Event"] == "ThingsOffline" then
        --设备下线事件
        g_event_report.thing_offline(body["Devices"])
    elseif body["Event"] == "StatusUpload" then
        --设备属性改变
        g_event_report.attribute_change(body)
    elseif body["Event"] == "ResultUpload" then
        --命令操作结果反馈
        g_event_report.method_respone(body)
    elseif body["Event"] == "RunningStatus" then
        --联动事件
        g_event_report.linkage_event(body)
    elseif body["Event"] == "PlatStatus" then
        --平台上线下线事件
        g_event_report.platform_online_event(body)
    end
end

-------main function------------
local request_method = ngx.var.request_method
if request_method == "GET" then
    get_method()
elseif request_method == "POST" then
    post_method()
elseif request_method == "PUT" then
    put_method()
elseif request_method == "DELETE" then
    delete_method()
end
