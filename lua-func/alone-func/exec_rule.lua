local m_exec_rule = {}


--load module
local g_rule_common = require("alone-func.rule_common")
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_dev_dft = require("alone-func.dev_default")
local g_tstatus = require("alone-func.time_rule_status")
local g_report_event = require("alone-func.rule_report_event")

local rules_table = {}

local exec_dev_only = true
local rule_module_idle = true

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
    local actions = cjson.decode(rule_obj["actions"])

    for i,action in ipairs(actions) do
        if action["Method"] == "SetOnOff" then
            local param = action["RuleParam"]
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
    end

    return true
end

--更新策略运行状态
local function update_rule_run_status(rule_obj)
    --清除该channel所有策略的running为0
    local res,err = g_sql_app.update_rule_tbl_running(rule_obj["dev_type"], rule_obj["dev_id"], rule_obj["dev_channel"], 0)
    if err then
        ngx.log(ngx.ERR," ",res.."  err msg: ",err)
        return false
    end

    --设置channel当前执行策略的running为1
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
local function exec_a_method(rule)
    --生成微服务报文
    local http_param_table = g_rule_common.encode_http_downstream_param(rule)
    --请求微服务
    local err = g_rule_common.exec_http_request(http_param_table)
    if err == false then
        ngx.log(ngx.ERR,"request http fail ")
        return 8, "device not ready"
    end
    
    --插入redis
    g_tstatus.add(http_param_table)

    --等待ResultUpload
    local msrvcode, desp
    while true do
        ngx.log(ngx.DEBUG,"check rule result-upload: ", rule["rule_uuid"].."  "..http_param_table["MsgId"])
        msrvcode, desp = g_tstatus.check_result_upload(http_param_table["MsgId"])
        ngx.log(ngx.DEBUG,"check "..http_param_table["MsgId"]..": ", msrvcode, desp)

        if msrvcode == nil then
            --本条method ResultUpload未收到，继续检查
            coroutine.yield(false, false)
        else
            --收到，返回结果
            break
        end        
    end
    ngx.log(ngx.DEBUG,"exec ", rule["rule_uuid"].."  "..http_param_table["MsgId"].." complete")

    --删除redis
    g_tstatus.del(http_param_table["MsgId"])

    return msrvcode, desp
end

local function exec_rule_group(rule)
    --检测微服务是否在线
    local rt = g_rule_common.check_dev_status(rule["dev_type"], rule["dev_id"], "online")
    if rt == false then
        ngx.log(ngx.NOTICE,"srv is offline, ignore rule! ")
        g_report_event.report_rule_exec_status(rule, "Start", 0, nil, nil)
        return true, false
    end
    --检测联动是否在执行
    local rt = g_rule_common.check_dev_status(rule["dev_type"], rule["dev_id"], "linkage")
    if rt == true then
        ngx.log(ngx.NOTICE,"linkage rule running, ignore rule! ")
        g_report_event.report_rule_exec_status(rule, "Start", 0, nil, nil)
        return true, false
    end
    --检测是否手动模式
    local rt = g_rule_common.check_dev_status(rule["dev_type"], rule["dev_id"], "cmd")
    if rt == true then
        ngx.log(ngx.NOTICE,"cmd running, ignore rule! ")
        g_report_event.report_rule_exec_status(rule, "Start", 0, nil, nil)
        return true, false
    end

    --执行策略组
    local actions = cjson.decode(rule["actions"])
    for i,action in ipairs(actions) do
        rule["method"] = action["Method"]
        rule["rule_param"] = cjson.encode(action["RuleParam"])
        ngx.log(ngx.INFO,"exec ", rule["dev_type"].." : "..rule["method"])
        --dump_rule(rule)

        local msrvcode, desp = exec_a_method(rule)
        --msrvcode = 1  --测试用
        if msrvcode ~= 0 then
            --ResultUpload错
            g_report_event.report_rule_exec_status(rule, "Start", i, msrvcode, desp)
            return true, false
        end
        --执行成功，执行下一个method
    end

    --update running
    local err = update_set_off_status(rule)
    if err == false then
        ngx.log(ngx.ERR,"update set off running fail ")
        return true, false
    end
    local err = update_rule_run_status(rule)
    if err == false then
        ngx.log(ngx.ERR,"update rules running fail ")
        return true, false
    end

    --上报成功状态
    g_report_event.report_rule_exec_status(rule, "Start", #actions, 0, "Success")

    return true, true
end

local function exec_rules_in_coroutine()
    if next(rules_table) == nil then
        ngx.log(ngx.INFO,"box has no rules to exec")
        return nil
    end

    local rule_coroutine = {}
    local has_failed = false

    for i,rule in ipairs(rules_table) do
        --ngx.log(ngx.NOTICE,"rules_table: ", cjson.encode(rule))
        --创建协程对象
        ngx.log(ngx.DEBUG,rule["dev_type"].." coroutine")
        rule_coroutine[i] = coroutine.create(exec_rule_group)
    end
    --ngx.log(ngx.DEBUG,"rule_coroutine cnt: ", #rule_coroutine)

    while next(rule_coroutine) ~= nil do
        ngx.log(ngx.DEBUG,"rule_coroutine cnt: ", #rule_coroutine)
        for i=1,#rule_coroutine do
            --ngx.sleep(0.1)
            ngx.log(ngx.DEBUG,"resume rule: ", rules_table[i]["rule_uuid"])
            local coroutinert, complete, msrvcode = coroutine.resume(rule_coroutine[i], rules_table[i])
            ngx.log(ngx.DEBUG,"resume return: ", coroutinert, complete, msrvcode)

            if complete == true then
                --策略组执行完成
                if msrvcode == true then
                    ngx.log(ngx.DEBUG,rules_table[i]["rule_uuid"].." exec rule complete and success")
                else
                    ngx.log(ngx.DEBUG,rules_table[i]["rule_uuid"].." exec rule complete and fail")
                    --有执行失败的策略，需要重试
                    has_failed = true
                end
                --本条策略已不需要执行，从执行序列删除
                table.remove(rule_coroutine, i)
                table.remove(rules_table, i)
                break
            else
                --策略组执行未完成
                ngx.log(ngx.DEBUG,rules_table[i]["rule_uuid"].." exec rule not complete")
            end
        end
    end

    ngx.log(ngx.INFO,"all rules complete")
    return has_failed
end

local function rule_exec_end_and_set_dft(dev_type, dev_id, channel)
    local sql_str = string.format("select * from run_rule_tbl where dev_type=\'%s\' and dev_id=%d and dev_channel=%d and running=1", dev_type, dev_id, channel)
    local res,err = g_sql_app.query_table(sql_str)
    if err then
        ngx.log(ngx.ERR," ", res,err)
        return nil
    end

    if next(res) ~= nil then
        --策略已结束，上报结束报文
        g_report_event.report_rule_exec_status(res[1], "End", 0, nil, nil)
    else
        --设备设置了时间策略，但是当前时间没有可执行策略，设为默认状态
        local set_dft_status = g_dev_dft.set_channel_dft(dev_type, dev_id, channel)
        return set_dft_status
    end
end


--执行设备某个channel的策略
function m_exec_rule.exec_rules_by_channel(dev_type, dev_id, channel)
    --选择最优的一条策略
    local ruletable, err = g_sql_app.query_rule_tbl_by_channel(dev_type, dev_id, channel)
    if err then
        ngx.log(ngx.ERR,"select rule error: ", err)
        return nil
    end

    if next(ruletable) == nil then
        --上报结束报文
        rule_exec_end_and_set_dft(dev_type, dev_id, channel)

        --channel当前时间没有可执行的策略，清除该channel所有策略的running为0
        ngx.log(ngx.NOTICE,"no rules available to exec ")
        local res,err = g_sql_app.update_rule_tbl_running(dev_type, dev_id, channel, 0)
        if err then
            ngx.log(ngx.ERR," ",res.."  err msg: ",err)
            return false
        end

        --设置默认状态
        local set_dft_status = rule_exec_end_and_set_dft(dev_type, dev_id, channel)
        return set_dft_status
    else
        for i,rule in ipairs(ruletable) do
            ngx.log(ngx.INFO,"exec time rule: uuid=", rule["rule_uuid"])

            if (rule["running"] == 1) then
                --策略已经在执行
                ngx.log(ngx.NOTICE,"rule is already running ")
            else
                --将可执行的策略插入表
                table.insert(rules_table, rule)
            end
        end
    end

    return true
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
        local set_dft_status = g_dev_dft.set_dev_dft(dev_type, dev_id)
        if set_dft_status == false then
            return true
        end
        return nil
    end

    for i=1,dev_channel_cnt do
        --ngx.log(ngx.INFO,"select rules in channel: ",dev_channel_array[i])
        m_exec_rule.exec_rules_by_channel(dev_type, dev_id, dev_channel_array[i])
    end

    local has_failed
    if exec_dev_only then
        ngx.log(ngx.INFO,"exec rules in device level by coroutine")
        has_failed = exec_rules_in_coroutine()
    end
    return has_failed
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
    while rule_module_idle == false do
        ngx.sleep(0.5)
    end
    exec_dev_only = false
    rule_module_idle = false
    local dev_type_array, dev_type_cnt = query_device_type()
    --ngx.log(ngx.INFO,"device type cnt: ", dev_type_cnt.." ".."device type list :", cjson.encode(dev_type_array))

    if next(dev_type_array) == nil
    then
        ngx.log(ngx.NOTICE,"has no type")
        rule_module_idle = true
        local set_dft_status = g_dev_dft.set_all_dev_dft()
        if set_dft_status == false then
            return true
        end
        return nil
    end

    for i=1,dev_type_cnt do
        --ngx.log(ngx.INFO,"select device in type: ",dev_type_array[i])
        m_exec_rule.exec_rules_by_type(dev_type_array[i])
    end

    ngx.log(ngx.INFO,"exec all rules by coroutine")
    local has_failed = exec_rules_in_coroutine()
    exec_dev_only = true
    rule_module_idle = true

    --设置无时间策略的设备为默认状态，有策略的不管
    local set_dft_status = g_dev_dft.set_all_dev_dft()
    if set_dft_status == false then
        has_failed = true
    end

    return has_failed
end


return m_exec_rule