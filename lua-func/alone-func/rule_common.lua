local m_rule_common = {}

--手动命令的优先级定义
--m_rule_common.cmd_priority = 1
--时间策略最大优先级定义
m_rule_common.time_priority_h = 8
m_rule_common.time_priority_l = 13
--24h的秒数 24*3600
local hours24 = 86400
--关闭设备
m_rule_common.set_off = 0


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
	dst_obj["Method"]    = src_obj["method"]
	dst_obj["Priority"]  = src_obj["priority"]

	dst_obj["RuleParam"] = src_obj["rule_param"]
	dst_obj["StartTime"] = src_obj["start_time"]
	dst_obj["EndTime"]   = src_obj["end_time"]
	dst_obj["StartDate"] = src_obj["start_date"]
    dst_obj["EndDate"]   = src_obj["end_date"]
	dst_obj["Running"]   = src_obj["running"]

	dst_obj["RuleParam"] = cjson.decode(dst_obj["RuleParam"])
	
	return dst_obj
end

--去除从数据库查到字段的首尾空格
function m_rule_common.db_str_trim(rule_obj)
    rule_obj["rule_uuid"]  = string.gsub(rule_obj["rule_uuid"], "%s+", "")
    rule_obj["dev_type"]   = string.gsub(rule_obj["dev_type"], "%s+", "")
    rule_obj["method"]     = string.gsub(rule_obj["method"], "%s+", "")
    
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
    if rule_obj["Method"] ~= nil then
        rule_obj["Method"]    = string.gsub(rule_obj["Method"], "%s+", "")
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
        return 0,false
    end
    local etime_table,err = g_sql_app.query_table(sql_etime)
    if err then
        ngx.log(ngx.ERR," ", err)
        return 0,false
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
                return 0,false
            end
            start_interval = hours24 - stime[1]["date_part"]
        end

        if (next(etime_table) ~= nil) then
            local sql_esec = string.format("select extract(epoch from ((current_time(0) - \'%s\')::time))", etime_table[1]["end_time"])
            local etime,err = g_sql_app.query_table(sql_esec)
            if err then
                ngx.log(ngx.ERR," ", err)
                return 0,false
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
            return 0,false
        end
        if (next(rule_table) ~= nil) then
            --日期内有策略，但在次日
            local sql_sec = string.format("select extract(epoch from ((current_time(0) - '24:00:00')::time))")
            local time,err = g_sql_app.query_table(sql_sec)
            if err then
                ngx.log(ngx.ERR," ", err)
                return 0,false
            end
            
            interval = hours24 - time[1]["date_part"]
        else
            --日期内无策略
            interval = 99999
        end
    end

    return (interval+1), true
end

-------------------------------------------------------------------------------------
--检查微服务状态
-------------------------------------------------------------------------------------
function m_rule_common.check_dev_status(dev_type, dev_id, attr)
    local svr_online = 0
    local linkage_run = 0
    local auto_mode = 0
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
    end
    
    if attr == "online" then
        --判断微服务是否在线
        ngx.log(ngx.INFO,"check svr_online: ", svr_online)
        if svr_online == 1 then
            ngx.log(ngx.INFO,"svr is online")
            return true     --在线
        else
            return false    --离线
        end
    elseif attr == "linkage" then
        --判断设备是否有联动在执行
        ngx.log(ngx.INFO,"check linkage_run: ", linkage_run)
        if linkage_run == 1 then
            ngx.log(ngx.INFO,"linkage is running")
            return true     --有联动在执行        
        else
            return false    --没有联动
        end
    elseif attr == "cmd" then
        --判断设备是否在手动模式
        ngx.log(ngx.INFO,"check auto_mode: ", auto_mode)
        if auto_mode == 0 then
            ngx.log(ngx.INFO,"cmd is running")
            return true     --手动模式        
        else
            return false    --自动模式
        end
    end
end

-------------------------------------------------------------------------------------
--请求http方法
-------------------------------------------------------------------------------------
--发起http请求
function m_rule_common.request_http(protocol,url,cmd_param)
    ngx.log(ngx.INFO,"rule http_uri: ", url)
    ngx.log(ngx.INFO,"rule http_body: ", cmd_param)

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
local function encode_http_downstream_param(rule_obj)
    local http_param_table = {}
    math.randomseed(os.time())

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
function m_rule_common.exec_http_request(rule_obj)
    local http_param_table = encode_http_downstream_param(rule_obj)
    if next(http_param_table["In"]) == nil then
        ngx.log(ngx.INFO,"rule param is nil")
        --return false
    end

    local http_param_str = cjson.encode(http_param_table)
    ngx.log(ngx.INFO,"time rule request msrv: ", rule_obj["dev_type"].." - "..http_param_str)

    local res, err = g_micro.micro_post(rule_obj["dev_type"], http_param_str)
    if err == false then
        ngx.log(ngx.ERR,"http request micro service fail: ",res, err)
        return false
    end

    return true
end

return m_rule_common