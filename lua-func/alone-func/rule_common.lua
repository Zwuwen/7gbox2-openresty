local m_rule_common = {}

--手动命令的优先级定义
m_rule_common.cmd_priority = 1
--24h的秒数 24*3600
local hours24 = 86400


--load module
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_http = require("common.http.myhttp_M")



--生成rule_module字段值
function m_rule_common.depend_rule_module(dev_type)
	local rule_module
	if dev_type == 'InfoScreen' then
		rule_module = 'strategy.screen_strategy'
	elseif dev_type == 'Led' then
		rule_module = 'strategy.led_strategy'
	elseif dev_type == 'Camera' then
		rule_module = 'strategy.camera_strategy'
    	else
        	ngx.log(ngx.ERR,"module err")
		rule_module = nil
	end

	return rule_module
end

--去除从数据库查到字段的首尾空格
function m_rule_common.db_str_trim(rule_obj)
    rule_obj["rule_uuid"]  = string.gsub(rule_obj["rule_uuid"], "%s+", "")
    rule_obj["dev_type"]   = string.gsub(rule_obj["dev_type"], "%s+", "")
    rule_obj["method"]     = string.gsub(rule_obj["method"], "%s+", "")
    rule_obj["rule_module"]= string.gsub(rule_obj["rule_module"], "%s+", "")
    
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
    if rule_obj["RuleModule"] ~= nil then
        rule_obj["RuleModule"]= string.gsub(rule_obj["RuleModule"], "%s+", "")
    end

    return rule_obj
end

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
            interval = 9
        end
    end

    return (interval+1), true
end

--发起http请求
function m_rule_common.request_http(protocol,url,cmd_param)
    ngx.log(ngx.INFO,"http_uri: ", url)
    ngx.log(ngx.INFO,"http_body: ", cmd_param)

    g_http.init()
    
    local res,status = g_http.request_url(url,protocol,cmd_param)
    if status == false then
        ngx.log(ngx.ERR,"http status: ", res,status)
    end
    g_http.uninit()
end

return m_rule_common