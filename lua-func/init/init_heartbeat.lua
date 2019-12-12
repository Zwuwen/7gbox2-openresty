local heartbeat_M={}
--Initialization miceoserver heartbeat
g_http = require("common.http.myhttp_M")
g_sql_app = require("common.sql.g_orm_info_M")

------------睡眠函数 单位s-------------------
function sleep(time)
    os.execute("sleep " .. time)
end
----------给微服务发送get心跳-----------------
function get_micro_heart(url)
    g_http.init()
    for count=1,3 do
        local res,status = g_http.request_url(url, "GET", "")
        if status == true then
            g_http.uninit()
            return true
        end
        sleep(2)
    end
    g_http.uninit()
    return false
end

------------更新微服务状态--------------
function update_server_status(dev_type,online)
    local update_json = {}
    update_json["online"] = online
    local res,err=g_sql_app.update_micro_svr_tbl(dev_type,update_json)
end

-----------更新微服务下设备状态---------
function update_devices_status(dev_type,online)
    local res,err = g_sql_app.query_dev_info_tbl_id(dev_type)
    for key,dev in ipairs(res) do
        local dev_id = dev["dev_id"]
        ngx.log(ngx.ERR, "dev_id:", dev_id)
        local update_json = {}
        update_json["online"] = online
        g_sql_app.update_dev_status_tbl(dev_id,update_json)
    end
end

--------------time task-----------------
function heartbeat_M.time_task_exec()
    local res,err = g_sql_app.query_micro_svr_all()
    for key,micro_svr in ipairs(res) do
        local url_prefix = micro_svr["url_prefix"]
        local online = micro_svr["online"]
        if online == 1 then
            local url = string.format("%s/heartbeat",url_prefix)
            local status = get_micro_heart(url)
            if (status == false) and (online == 1) then
                local dev_type = micro_svr["dev_type"]
                update_server_status(dev_type,0)
                update_devices_status(dev_type,0)
            end
        end
    end
end

return heartbeat_M