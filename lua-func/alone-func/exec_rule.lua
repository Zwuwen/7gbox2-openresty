local m_exec_rule = {}


--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_dev_dft = require("alone-func.dev_default")

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

--
local function check_dev_status(dev_type, dev_id, attr)
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

function m_exec_rule.clear_device_running(dev_type, dev_id)
    local sql_str = string.format("update run_rule_tbl set running=0 where dev_type=\'%s\' and dev_id=%d", dev_type, dev_id)
    
    local res, err = g_sql_app.exec_sql(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res, err)
        return false
    end
    return true
end

--更新设备关闭时所有策略的运行状态
local function update_set_off_status(rule_obj)
    if rule_obj["method"] == "SetOnOff" then
        local param = cjson.decode(rule_obj["rule_param"])
        if param["OnOff"] == g_rule_common.set_off then
            ngx.log(ngx.INFO,"update turn off dev: ", rule_obj["dev_type"].." "..rule_obj["dev_id"])
            local err = m_exec_rule.clear_device_running(rule_obj["dev_type"], rule_obj["dev_id"])
            if err == false then
                ngx.log(ngx.ERR,"update turn off dev fail ")
                return false
            end
        else
            --开启
        end
    else
        --其他方法，不需要更新
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
    --检测微服务是否在线
    local rt = check_dev_status(rule_obj["dev_type"], rule_obj["dev_id"], "online")
    if rt == false then
        ngx.log(ngx.NOTICE,"srv is offline, ignore rule! ")
        return false
    end
    --检测联动是否在执行
    local rt = check_dev_status(rule_obj["dev_type"], rule_obj["dev_id"], "linkage")
    if rt == true then
        ngx.log(ngx.NOTICE,"linkage rule running, ignore rule! ")
        return false
    end
    --检测是否手动模式
    local rt = check_dev_status(rule_obj["dev_type"], rule_obj["dev_id"], "cmd")
    if rt == true then
        ngx.log(ngx.NOTICE,"cmd running, ignore rule! ")
        return false
    end
    --执行rule
    local err = g_rule_common.exec_http_request(rule_obj)
    if err == false then
        ngx.log(ngx.ERR,"request http fail ")
        return false
    end
    
    --update running
    local err = update_set_off_status(rule_obj)
    if err == false then
        ngx.log(ngx.ERR,"update set off running fail ")
        return false
    end
    local err = update_rule_run_status(rule_obj)
    if err == false then
        ngx.log(ngx.ERR,"update rules running fail ")
        return false
    end

    return true
end

--执行设备某个channel某个method的策略
function m_exec_rule.exec_rules_by_method(dev_type, dev_id, channel, method)
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
                --ngx.update_time()
                --ngx.log(ngx.INFO,"---------time1: ", ngx.now())
                ngx.sleep(0.5)
                --ngx.update_time()
                --ngx.log(ngx.INFO,"---------time2: ", ngx.now())
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

    --设置设备默认状态——dev当前时间无可执行策略时
    local sql_str = string.format("select * from run_rule_tbl where dev_type=\'%s\' and dev_id=%d and dev_channel=%d and running=1", dev_type, dev_id, channel)
    local res,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res,err)
        return err, false
    end
    if next(res) == nil then
        ngx.log(ngx.INFO,"set "..dev_type.."-"..dev_id.." to default status")
        g_dev_dft.set_dev_dft(dev_type, dev_id, channel)
    end
end

--执行某个设备的策略
function m_exec_rule.exec_rules_by_devid(dev_type, dev_id)
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

    --设置设备默认状态——dev无策略时
    g_dev_dft.set_all_dev_dft()
end


return m_exec_rule