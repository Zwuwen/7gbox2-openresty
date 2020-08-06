--eventfunction
--restful parsing parameters

--const define

--load module
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_event_report = require("event-func.event_report")
local g_sql_app = require("common.sql.g_orm_info_M")

local m_event_handle = {}
local g_event_handle_body_table = {}
local g_is_event_handle_timer_running = false
local g_event_handle_body_table_locker = false


------------------------------------event handle function api-----------------------------------------
local function get_method()
    
end

local function put_method()
    
end

local function delete_method()
    
end

local function linkage_event_handle(premature, data)
    g_event_report.linkage_event(data)
end

-------------post method---------
local function post_method(request_body)
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
    elseif body["Event"] == "LinkageRuleStatus" then
        --联动事件
        ngx.timer.at(0, linkage_event_handle, body)
    elseif body["Event"] == "PlatStatus" then
        --平台上线下线事件
        g_event_report.platform_online_event(body)
    elseif body["Event"] == "Alarm" then
        --AI事件
        g_event_report.attribute_change(body)
    elseif body["Event"] == "TimerRuleStatus" then
        --时间策略执行状态
        g_event_report.transmit_do_nothing(body)
    else
        ngx.log(ngx.DEBUG,"handle post event failed")
        return
    end
end

local function event_handle(request_method, request_body)
    if request_method == "GET" then
        get_method()
    elseif request_method == "POST" then
        post_method(request_body)
    elseif request_method == "PUT" then
        put_method()
    elseif request_method == "DELETE" then
        delete_method()
    end
end

function m_event_handle.add_handle(request_method, request_body)
	local request_table = {request_method, request_body}
	while true do
		if not g_event_handle_body_table_locker then
            g_event_handle_body_table_locker = true
            table.insert(g_event_handle_body_table, request_table)
            g_event_handle_body_table_locker = false
            break
        else
            ngx.sleep(0.01)
		end
	end
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

function m_event_handle.event_handle_thread()
	if g_is_event_handle_timer_running == false then
		g_is_event_handle_timer_running = true
		local want_remove = {}
		for k, v in ipairs(g_event_handle_body_table) do
            local request_method = v[1]
            local request_body = v[2]
            event_handle(request_method, request_body)
			table.insert(want_remove, k)
		end
		---remove table what has been handle
        if next(want_remove)~= nil then
            while true do
                if not g_event_handle_body_table_locker then
                    g_event_handle_body_table_locker = true
                    g_event_handle_body_table = remove_table(g_event_handle_body_table, want_remove)
                    g_event_handle_body_table_locker = false
                    break
                else
                    ngx.sleep(0.01)
                end
            end
        end
		g_is_event_handle_timer_running = false
	end
end

return m_event_handle