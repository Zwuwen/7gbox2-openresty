local m_exec_rule = {}


--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_micro = require("cmd-func.cmd_micro")
local g_dev_status = require("dev-status-func.dev_status")
local g_linkage_sync = require("alone-func.linkage_sync")

--function define
---------------------策略自动执行-----------------------------------
local function dump_rule(rule_obj)
    ngx.log(ngx.INFO ,"rule_uuid  : ",rule_obj["rule_uuid"])
    ngx.log(ngx.INFO ,"dev_type   : ",rule_obj["dev_type"])
    ngx.log(ngx.INFO ,"dev_id     : ",rule_obj["dev_id"])
    ngx.log(ngx.INFO ,"dev_channel: ",rule_obj["dev_channel"])
    ngx.log(ngx.INFO ,"method     : ",rule_obj["method"])
    ngx.log(ngx.INFO ,"priority   : ",rule_obj["priority"])
    ngx.log(ngx.INFO ,"rule_param : ",rule_obj["rule_param"])
    ngx.log(ngx.INFO ,"start_time : ",rule_obj["start_time"])
    ngx.log(ngx.INFO ,"end_time   : ",rule_obj["end_time"])
    ngx.log(ngx.INFO ,"start_date : ",rule_obj["start_date"])
    ngx.log(ngx.INFO ,"end_date   : ",rule_obj["end_date"])
    ngx.log(ngx.INFO ,"running    : ",rule_obj["running"])
end

--获取数据库中策略的所有设备类型
local function query_device_type()
    local dev_type_table,err = g_sql_app.query_rule_tbl_for_devtype()
    if err then
        ngx.log(ngx.ERR," ",dev_type_table.."  err msg: ",err)
        return {},0--for next(table)
    end

    local dev_type_array = {}
    local dev_type_cnt = 0

    if next(dev_type_table) == nil
    then
        --ngx.log(ngx.INFO,"dev_type null")
    else
        --ngx.log(ngx.INFO,"has dev_type")
        -- i=1,2,3...
        for i,w in ipairs(dev_type_table) do
            dev_type_array[i] = w["btrim"]--dev_type
            dev_type_cnt = i
        end
    end

    return dev_type_array, dev_type_cnt
end

--获取数据库中某类型的所有设备
local function query_device_id(dev_type)
    local dev_id_table,err = g_sql_app.query_rule_tbl_for_devid(dev_type)
    if err then
        ngx.log(ngx.ERR," ",dev_id_table.."  err msg: ",err)
        return {},0--for next(table)
    end

    local dev_id_array = {}
    local dev_id_cnt = 0

    if next(dev_id_table) == nil
    then
        --ngx.log(ngx.INFO,"dev_id null")
    else
        --ngx.log(ngx.INFO,"has dev_id")
        -- i=1,2,3...
        for i,w in ipairs(dev_id_table) do
            dev_id_array[i] = w["dev_id"]
            dev_id_cnt = i
        end
    end

    return dev_id_array, dev_id_cnt
end

--获取数据库中某个设备的所有channel
local function query_device_channel(dev_type, dev_id)
    local dev_channel_table,err = g_sql_app.query_rule_tbl_for_channel(dev_type, dev_id)
    if err then
        ngx.log(ngx.ERR," ",dev_channel_table.."  err msg: ",err)
        return {},0--for next(table)
    end

    local dev_channel_array = {}
    local dev_channel_cnt = 0

    if next(dev_channel_table) == nil
    then
        --ngx.log(ngx.INFO,"channel null")
    else
        --ngx.log(ngx.INFO,"has channel")
        -- i=1,2,3...
        for i,w in ipairs(dev_channel_table) do
            dev_channel_array[i] = w["dev_channel"]
            dev_channel_cnt = i
        end
    end

    return dev_channel_array, dev_channel_cnt
end

--获取dev某个channel的所有method
local function query_device_method(dev_type, dev_id, channel)
    local dev_method_table,err = g_sql_app.query_rule_tbl_for_method(dev_type, dev_id, channel)
    if err then
        ngx.log(ngx.ERR," ",dev_method_table.."  err msg: ",err)
        return {},0--for next(table)
    end

    local dev_method_array = {}
    local dev_method_cnt = 0

    if next(dev_method_table) == nil
    then
        --ngx.log(ngx.INFO,"method null")
    else
        --ngx.log(ngx.INFO,"has method")
        -- i=1,2,3...
        for i,w in ipairs(dev_method_table) do
            dev_method_array[i] = w["btrim"]--method
            dev_method_cnt = i
        end
    end

    return dev_method_array, dev_method_cnt
end

--打包HTTP请求数据
local function encode_http_downstream_param(rule_obj)
    local http_param_table = {}
    math.randomseed(os.time())

    http_param_table["Token"]     = '7GBox_rule'
    http_param_table["MsgId"]	  = "time_"..os.date("%y%m%d-%H%M%S")..tostring(math.random(10,99))
    http_param_table["DevType"]   = rule_obj["dev_type"]
    http_param_table["DevId"]     = rule_obj["dev_id"]
    http_param_table["DevChannel"]= rule_obj["dev_channel"]
    http_param_table["Method"]    = rule_obj["method"]
    local in_obj                  = cjson.decode(rule_obj["rule_param"])
    http_param_table["In"]        = in_obj

    return http_param_table
end

--给微服务发送HTTP请求
local function exec_http_request(rule_obj)
    local http_param_table = encode_http_downstream_param(rule_obj)
    if next(http_param_table["In"]) == nil then
        ngx.log(ngx.ERR,"rule param error ")
        return false
    end

    local http_param_str = cjson.encode(http_param_table)

    local res, err = g_micro.micro_post(rule_obj["dev_type"], http_param_str)
    if err == false then
        ngx.log(ngx.ERR,"http request micro service fail: ",res, err)
        return false
    end

    return true
end

--更新策略运行状态
local function update_rule_run_status(rule_obj)
    --清除该method所有策略的running为0
    local res,err = g_sql_app.update_rule_tbl_running(rule_obj["dev_type"], rule_obj["dev_id"], rule_obj["dev_channel"], rule_obj["method"], 0)
    if err then
        ngx.log(ngx.ERR," ",res.."  err msg: ",err)
        return false
    end

    --设置method当前执行策略的running为1
    local run_flag = {}
    run_flag["Running"] = 1
    local res,err = g_sql_app.update_rule_tbl(rule_obj["rule_uuid"], run_flag)
    if err then
        ngx.log(ngx.ERR," ",res.."  err msg: ",err)
        return false
    end

    return true
end

--执行策略
local function exec_a_rule(rule_obj)
    --dump_rule(rule_obj)
    if (rule_obj["priority"] == g_rule_common.cmd_priority) then
        --手动命令，不执行
        ngx.log(ngx.NOTICE  ,"cmd running, ignore rule! ")
    else
        --执行rule
        local err = exec_http_request(rule_obj)
        if err == false then
            ngx.log(ngx.ERR,"request http fail ")
            return false
        end

        --执行成功
    end
    
    --update running
    local err = update_rule_run_status(rule_obj)
    if err == false then
        ngx.log(ngx.ERR,"update rules running fail ")
        return false
    end

    return true
end

--执行设备某个channel某个method的策略
function m_exec_rule.exec_rules_by_method(dev_type, dev_id, channel, method)
    local rt = g_linkage_sync.check_linkage_running(dev_type, dev_id)
    if rt == false then
        ngx.log(ngx.NOTICE,"linkage rule running, ignore rule! ")
        return false
    end

    --选择最优的一条策略
    local ruletable, err = g_sql_app.query_rule_tbl_by_method(dev_type, dev_id, channel, method)
    if err then
        ngx.log(ngx.ERR,"select rule error: ", err)
        return false
    end

    if next(ruletable) == nil then
        --method当前时间没有可执行的策略，清除该method所有策略的running为0
        ngx.log(ngx.NOTICE,"no rules available to exec ")
        local res,err = g_sql_app.update_rule_tbl_running(dev_type, dev_id, channel, method, 0)
        if err then
            ngx.log(ngx.ERR," ",res.."  err msg: ",err)
            return false
        end
    else
        for i,rule in ipairs(ruletable) do
            ngx.log(ngx.INFO,"exec time rule: uuid=", rule["rule_uuid"])
            --去除字符串首尾空格
            rule = g_rule_common.db_str_trim(rule)

            if (rule["running"] == 1) then
                --策略已经在执行
                ngx.log(ngx.NOTICE,"rule is already running ")
            else
                --执行策略
                local err = exec_a_rule(rule)
                if err == false then
                    ngx.log(ngx.ERR,"exec rule fail ")
                    return false
                end
            end
        end
    end

    return true
end

--执行设备某个channel的策略
function m_exec_rule.exec_rules_by_channel(dev_type, dev_id, channel)
    local dev_method_array, dev_method_cnt = query_device_method(dev_type, dev_id, channel)
    ngx.log(ngx.INFO,"device method cnt: ", dev_method_cnt.." ".."device method list :", cjson.encode(dev_method_array))

    if next(dev_method_array) == nil
    then
        ngx.log(ngx.NOTICE,"has no method")
        return-------------
    end

    for i=1,dev_method_cnt do
        ngx.log(ngx.INFO,"exec rules in method: ",dev_method_array[i])
        m_exec_rule.exec_rules_by_method(dev_type, dev_id, channel, dev_method_array[i])
    end
end

--执行某个设备的策略
function m_exec_rule.exec_rules_by_devid(dev_type, dev_id)
    local rt = g_linkage_sync.check_linkage_running(dev_type, dev_id)
    if rt == false then
        ngx.log(ngx.NOTICE,"linkage is running")
        return
    end

    --执行设备策略
    local dev_channel_array, dev_channel_cnt = query_device_channel(dev_type, dev_id)
    --ngx.log(ngx.INFO,"device channel cnt: ", dev_channel_cnt.." ".."device channel list :", cjson.encode(dev_channel_array))

    if next(dev_channel_array) == nil
    then
        ngx.log(ngx.NOTICE,"has no channel")
        return-------------
    end

    for i=1,dev_channel_cnt do
        --ngx.log(ngx.INFO,"select method in channel: ",dev_channel_array[i])
        m_exec_rule.exec_rules_by_channel(dev_type, dev_id, dev_channel_array[i])
    end
end

--执行某一类设备的策略
function m_exec_rule.exec_rules_by_type(dev_type)
    local dev_id_array, dev_id_cnt = query_device_id(dev_type)
    --ngx.log(ngx.INFO,"device id cnt: ", dev_id_cnt.." ".."device id list :", cjson.encode(dev_id_array))

    if next(dev_id_array) == nil
    then
        ngx.log(ngx.NOTICE,"has no device")
        return-------------
    end

    for i=1,dev_id_cnt do
        ngx.log(ngx.INFO,"select channel in device: ",dev_id_array[i])
        m_exec_rule.exec_rules_by_devid(dev_type, dev_id_array[i])
    end
end

--执行所有类型设备的策略
function m_exec_rule.exec_all_rules()
    local dev_type_array, dev_type_cnt = query_device_type()
    --ngx.log(ngx.INFO,"device type cnt: ", dev_type_cnt.." ".."device type list :", cjson.encode(dev_type_array))

    if next(dev_type_array) == nil
    then
        ngx.log(ngx.NOTICE,"has no type")
        return-------------
    end

    for i=1,dev_type_cnt do
        --ngx.log(ngx.INFO,"select device in type: ",dev_type_array[i])
        m_exec_rule.exec_rules_by_type(dev_type_array[i])
    end
end


return m_exec_rule