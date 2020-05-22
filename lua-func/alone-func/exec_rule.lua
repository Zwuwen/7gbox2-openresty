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

--
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
    local res,err = g_sql_app.update_rule_tbl_running(rule_obj["dev_type"], rule_obj["dev_id"], rule_obj["dev_channel"], 0)
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
local function exec_a_method(rule_obj)
    --dump_rule(rule_obj)
    --检测微服务是否在线
    local rt = g_rule_common.check_dev_status(rule_obj["dev_type"], rule_obj["dev_id"], "online")
    if rt == false then
        ngx.log(ngx.NOTICE,"srv is offline, ignore rule! ")
        return false
    end
    --检测联动是否在执行
    local rt = g_rule_common.check_dev_status(rule_obj["dev_type"], rule_obj["dev_id"], "linkage")
    if rt == true then
        ngx.log(ngx.NOTICE,"linkage rule running, ignore rule! ")
        return false
    end
    --检测是否手动模式
    local rt = g_rule_common.check_dev_status(rule_obj["dev_type"], rule_obj["dev_id"], "cmd")
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
function m_exec_rule.exec_rules_in_channel(dev_type, dev_id, channel)
    --选择最优的一条策略
    local ruletable, err = g_sql_app.query_rule_tbl_by_channel(dev_type, dev_id, channel)
    if err then
        ngx.log(ngx.ERR,"select rule error: ", err)
        return false
    end

    if next(ruletable) == nil then
        --channel当前时间没有可执行的策略，清除该channel所有策略的running为0
        ngx.log(ngx.NOTICE,"no rules available to exec ")
        local res,err = g_sql_app.update_rule_tbl_running(dev_type, dev_id, channel, 0)
        if err then
            ngx.log(ngx.ERR," ",res.."  err msg: ",err)
            return false
        end
    else
        for i,rule in ipairs(ruletable) do
            ngx.log(ngx.INFO,"exec time rule: uuid=", rule["rule_uuid"])

            if (rule["running"] == 1) then
                --策略已经在执行
                ngx.log(ngx.NOTICE,"rule is already running ")
            else
                --执行策略
                local actions = cjson.decode(rule["actions"])
                for i,action in ipairs(actions) do
                    rule["method"] = action["Method"]
                    rule["rule_param"] = cjson.encode(action["RuleParam"])

                    --
                    local err = exec_a_method(rule)
                    if err == false then
                        ngx.log(ngx.ERR,"exec rule fail ")
                        return false
                    end
                end
            end
        end
    end

    return true
end

--执行设备某个channel的策略
function m_exec_rule.exec_rules_by_channel(dev_type, dev_id, channel)
    m_exec_rule.exec_rules_in_channel(dev_type, dev_id, channel)

    --设置设备默认状态——dev当前时间无可执行策略时
    local sql_str = string.format("select * from run_rule_tbl where dev_type=\'%s\' and dev_id=%d and dev_channel=%d and running=1", dev_type, dev_id, channel)
    local res,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res,err)
        return err, false
    end
    if next(res) == nil then
        --设备设置了时间策略，但是当前时间没有可执行策略，设为默认状态
        g_dev_dft.set_channel_dft(dev_type, dev_id, channel)
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
        --从联动或手动模式恢复后没有时间策略时设置默认
        g_dev_dft.set_dev_dft(dev_type, dev_id)
        return-------------
    end

    for i=1,dev_channel_cnt do
        --ngx.log(ngx.INFO,"select rules in channel: ",dev_channel_array[i])
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
        g_dev_dft.set_all_dev_dft()
        return-------------
    end

    for i=1,dev_type_cnt do
        --ngx.log(ngx.INFO,"select device in type: ",dev_type_array[i])
        m_exec_rule.exec_rules_by_type(dev_type_array[i])
    end

    --设置无时间策略的设备为默认状态，有策略的不管
    g_dev_dft.set_all_dev_dft()
end


return m_exec_rule