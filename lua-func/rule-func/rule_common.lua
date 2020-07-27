local m_rule_common = {}

--手动命令的优先级定义
m_rule_common.cmd_priority = 8
--时间策略最大优先级定义
m_rule_common.time_priority_h = 8
m_rule_common.time_priority_l = 13
--24h的秒数 24*3600
local hours24 = 86400
--关闭设备
m_rule_common.set_off = 0

--设备类型定义
m_rule_common.lamp_type = "Lamp"
m_rule_common.screen_type = "InfoScreen"
m_rule_common.ipc_onvif_type = "IPC-Onvif"
m_rule_common.speaker_type = "Speaker"

--load module
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_http = require("common.http.myhttp_M")
local g_micro = require("cmd-func.cmd_micro")


--转换数据库字段名
function m_rule_common.db_attr_to_display(src_obj)
	local dst_obj = {}

	dst_obj["RuleUuid"]  = src_obj["rule_uuid"]
	dst_obj["DevType"]   = src_obj["dev_type"]
	dst_obj["DevId"]	 = src_obj["dev_id"]
	dst_obj["DevChannel"]= src_obj["dev_channel"]
	dst_obj["Priority"]  = src_obj["priority"]
	dst_obj["Actions"] = src_obj["actions"]
	dst_obj["StartTime"] = src_obj["start_time"]
	dst_obj["EndTime"]   = src_obj["end_time"]
	dst_obj["StartDate"] = src_obj["start_date"]
    dst_obj["EndDate"]   = src_obj["end_date"]
	dst_obj["Running"]   = src_obj["running"]

	dst_obj["Actions"] = cjson.decode(dst_obj["Actions"])
	
	return dst_obj
end

--去除从数据库查到字段的首尾空格
function m_rule_common.db_str_trim(rule_obj)
    rule_obj["rule_uuid"]  = string.gsub(rule_obj["rule_uuid"], "%s+", "")
    rule_obj["dev_type"]   = string.gsub(rule_obj["dev_type"], "%s+", "")
    
    return rule_obj
end

--去除HTTP数据字段的首尾空格
function m_rule_common.http_str_trim(rule_obj)
    if rule_obj["RuleUuid"] ~= nil then
        rule_obj["RuleUuid"]  = string.gsub(rule_obj["RuleUuid"], "%s+", "")
    end
    if rule_obj["DevType"] ~= nil then
        rule_obj["DevType"]   = string.gsub(rule_obj["DevType"], "%s+", "")
    end

    return rule_obj
end

-------------------------------------------------------------------------------------
--lua通用方法
-------------------------------------------------------------------------------------
--字符串在表中是否存在
function m_rule_common.is_include(value, table)
    for k,v in ipairs(table) do
      if v == value then
          return true
      end
    end
    return false
end

--表深拷贝
function m_rule_common.table_clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

--清空table
function m_rule_common.clear_table(atable)
    while next(atable) ~= nil do
        --print("table cnt: ", #atable)
        table.remove(atable)
    end
end

--获取系统运行时间
function m_rule_common.get_system_running_time()
    local time_file = io.popen('cat /proc/uptime | awk -F. \'{run_second=$1;printf("%d",run_second)}\'')
    local second_str = time_file:read("*all")
    local second_num = tonumber(second_str)
    ngx.log(ngx.INFO,"system running time: ", second_num)

    return second_num
end

-------------------------------------------------------------------------------------
--计算自动执行时间策略的间隔时间
-------------------------------------------------------------------------------------
--返回：
--成功：interval,true    日期内有策略
--      默认时间,true    日期内无策略
--失败：0,false
function m_rule_common.get_next_loop_interval()
    --查询距当前时间最小的start_time，end_time (hh:mm:ss)
    local sql_stime = string.format("select %s from run_rule_tbl where (start_date<=current_date and current_date<=end_date and %s>=current_time(0)) order by %s ASC limit 1", 'start_time','start_time','start_time')
    local sql_etime = string.format("select %s from run_rule_tbl where (start_date<=current_date and current_date<=end_date and %s>=current_time(0)) order by %s ASC limit 1", 'end_time','end_time','end_time')

    local stime_table,err = g_sql_app.query_table(sql_stime)
    if err then
        ngx.log(ngx.ERR," ", err)
        return nil,false
    end
    local etime_table,err = g_sql_app.query_table(sql_etime)
    if err then
        ngx.log(ngx.ERR," ", err)
        return nil,false
    end

    --start_time，end_time距当前时间转换成s
    local interval = 0
    if (next(stime_table) ~= nil) or (next(etime_table) ~= nil) then
        local start_interval = 0
        local end_interval   = 0

        if (next(stime_table) ~= nil) then
            local sql_ssec = string.format("select extract(epoch from ((current_time(0) - \'%s\')::time))", stime_table[1]["start_time"])
            local stime,err = g_sql_app.query_table(sql_ssec)
            if err then
                ngx.log(ngx.ERR," ", err)
                return nil,false
            end
            start_interval = hours24 - stime[1]["date_part"]
        end

        if (next(etime_table) ~= nil) then
            local sql_esec = string.format("select extract(epoch from ((current_time(0) - \'%s\')::time))", etime_table[1]["end_time"])
            local etime,err = g_sql_app.query_table(sql_esec)
            if err then
                ngx.log(ngx.ERR," ", err)
                return nil,false
            end
            end_interval   = hours24 - etime[1]["date_part"]
        end

        if (next(etime_table) == nil) then
            interval = start_interval
        elseif (next(stime_table) == nil) then
            interval = end_interval
        else
            if (start_interval >= end_interval) then
                interval = end_interval
            else
                interval = start_interval
            end
        end    
    elseif (next(stime_table) == nil) and (next(etime_table) == nil) then
        local sql_rule = string.format("select * from run_rule_tbl where (start_date<=current_date and current_date<=end_date)")
        local rule_table,err = g_sql_app.query_table(sql_rule)
        if err then
            ngx.log(ngx.ERR," ", err)
            return nil,false
        end
        if (next(rule_table) ~= nil) then
            --日期内有策略，但在次日
            local sql_sec = string.format("select extract(epoch from ((current_time(0) - '24:00:00')::time))")
            local time,err = g_sql_app.query_table(sql_sec)
            if err then
                ngx.log(ngx.ERR," ", err)
                return nil,false
            end
            
            interval = hours24 - time[1]["date_part"]
        else
            --日期内无策略
            return nil, true
        end
    end

    return (interval+1), true
end

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
--获取设备channel数
function m_rule_common.get_dev_channel_cnt(dev_type, dev_id)
    local res, err = g_sql_app.query_dev_status_tbl(dev_id)
    if err then
        ngx.log(ngx.ERR,"postgresql io err: ", err)
        return nil
    end
    if next(res) == nil then
        ngx.log(ngx.ERR,"device id not exist")
        return nil
    end
    
    local attribute = res[1]["attribute"]
    local attribute_tbl = cjson.decode(attribute)
    local channels = attribute_tbl["Channels"]
    --ngx.log(ngx.DEBUG,"channels: ", cjson.encode(channels))
    local channel_cnt = #channels
    --ngx.log(ngx.DEBUG,dev_type.."-"..dev_id.." channel_cnt: ", channel_cnt)
    return channel_cnt
end

-------------------------------------------------------------------------------------
--检查微服务状态
-------------------------------------------------------------------------------------
--设置设备默认状态标志
--1: 是默认状态
--0: 不是默认状态
function m_rule_common.set_dev_dft_flag(dev_type, dev_id, value)
    local sql_str = string.format("update dev_status_tbl set is_dft=%d where dev_id=%d", value, dev_id)
    
    local res, err = g_sql_app.exec_sql(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        return false
    end
    return true
end

--获取设备状态：在线状态、手动/自动模式、联动运行状态、默认状态
function m_rule_common.check_dev_status(dev_type, dev_id, attr)
    local svr_online = 0
    local linkage_run = 0
    local auto_mode = 0
    local is_dft = 0
    local res, err = g_sql_app.query_dev_status_tbl(dev_id)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        return false
    end
    if next(res) == nil then
        ngx.log(ngx.ERR,"device id not exist")
        return false
    else
        svr_online = res[1]["online"]
        linkage_run= res[1]["linkage_rule"]
        auto_mode  = res[1]["auto_mode"]
        is_dft     = res[1]["is_dft"]
    end
    
    if attr == "online" then
        --判断微服务是否在线
        --ngx.log(ngx.INFO,"check svr_online: ", svr_online)
        if svr_online == 1 then
            return true     --在线
        else
            ngx.log(ngx.INFO,"svr is offline")
            return false    --离线
        end
    elseif attr == "linkage" then
        --判断设备是否有联动在执行
        --ngx.log(ngx.INFO,"check linkage_run: ", linkage_run)
        if linkage_run ~= 0 then
            ngx.log(ngx.INFO,"linkage is running")
            return true     --有联动在执行        
        else
            return false    --没有联动
        end
    elseif attr == "cmd" then
        --判断设备是否在手动模式
        --ngx.log(ngx.INFO,"check auto_mode: ", auto_mode)
        if auto_mode == 0 then
            ngx.log(ngx.INFO,"cmd is running")
            return true     --手动模式        
        else
            return false    --自动模式
        end
    elseif attr == "default" then
        --判断设备是否在默认状态
        --ngx.log(ngx.INFO,"check default: ", is_dft)
        if is_dft == 1 then
            ngx.log(ngx.INFO,"device is default")
            return true     --默认状态
        else
            return false    --不是默认状态
        end
    end
end

-------------------------------------------------------------------------------------
--请求http方法
-------------------------------------------------------------------------------------
--发起http请求
function m_rule_common.request_http(protocol,url,cmd_param)
    --ngx.log(ngx.DEBUG,"rule http_uri: ", url)
    --ngx.log(ngx.DEBUG,"rule http_body: ", cmd_param)

    g_http.init()
    
    local res,status = g_http.request_url(url,protocol,cmd_param)
    if status == false then
        ngx.log(ngx.ERR,"http status: ", res,status)
    end
    g_http.uninit()
end

-------------------------------------------------------------------------------------
--请求微服务方法
-------------------------------------------------------------------------------------
--打包HTTP请求数据
math.randomseed(tostring(os.time()):reverse():sub(1, 7))
function m_rule_common.encode_http_downstream_param(rule_obj)
    local http_param_table = {}
    http_param_table["Token"]     = '7GBox_rule'
    http_param_table["MsgId"]	  = "time_"..os.date("%y%m%d-%H%M%S")..tostring(math.random(100,999))
    http_param_table["DevType"]   = rule_obj["dev_type"]
    http_param_table["DevId"]     = rule_obj["dev_id"]
    http_param_table["DevChannel"]= rule_obj["dev_channel"]
    http_param_table["Method"]    = rule_obj["method"]
    local in_obj                  = cjson.decode(rule_obj["rule_param"])
    http_param_table["In"]        = in_obj

    return http_param_table
end

--给微服务发送HTTP请求
function m_rule_common.exec_http_request(http_param_table)
    --local http_param_table = encode_http_downstream_param(rule_obj)
    if next(http_param_table["In"]) == nil then
        ngx.log(ngx.INFO,"rule param is nil")
        --return false
    end

    local http_param_str = cjson.encode(http_param_table)
    ngx.log(ngx.INFO,"time rule request msrv: ", http_param_table["DevType"].." - "..http_param_str)

    local res, err = g_micro.micro_post(http_param_table["DevType"], http_param_str)
    if err == false then
        ngx.log(ngx.ERR,"http request micro service fail: ",res, err)
        return false
    end

    return true
end

return m_rule_common