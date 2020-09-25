local time_rule_status = {}
local cjson = require("cjson")
local g_redis = require("common.redis.g_redis_M")


function time_rule_status.add(data) 
    local msgid = string.sub(data['MsgId'], 6)
    msgid = 'tstatus'..msgid
    local json_body = cjson.encode(data)
    local red
    red = g_redis.open_db(red)
    local ok = g_redis.redis_set(red, msgid, json_body)
    g_redis.close_db(red)  
end

function time_rule_status.query(msgid)  
    local cmd_status = {'Success', 'Failed', 'Waitting', 'Timeout', 'NotFound'}

    local mmsgid = 'tstatus'..string.sub(msgid, 6)
    local red
    red = g_redis.open_db(red)
    local res = g_redis.redis_get(red, mmsgid)
    g_redis.close_db(red)
    if res ~= nil then
        local json_body = cjson.decode(res)
        local payload = json_body['Payload']
        if payload ~= nil then
            local result = payload['Result']
            if result ~= 0 then
                return res, cmd_status[2]
            else
                return res, cmd_status[1]
            end
        else
            local year = '20'..string.sub(msgid, 6, 7)
            local month = string.sub(msgid, 8, 9)
            local day = string.sub(msgid, 10, 11)
            local hour = string.sub(msgid, 13, 14)
            local minute = string.sub(msgid, 15, 16)
            local second = string.sub(msgid, 17, 18)
            local ntime = os.time()
            local ltime = os.time({day = day, month = month, year = year, hour = hour})     
            ltime = ltime + tonumber(minute) * 60 + tonumber(second)
            if ntime - ltime > 20 then
                return res, cmd_status[4]
            else
                return res, cmd_status[3]
            end
        end  
    else
        return res, cmd_status[5] 
    end  
end

function time_rule_status.update(data)
    local ok = false
    local msgid = 'tstatus'..string.sub(data['MsgId'], 6)

    local red
    red = g_redis.open_db(red)
    local res = g_redis.redis_get(red, msgid)
    if res ~= nil then
        local json_body = cjson.decode(res)
        json_body['Payload'] = data['Payload']
        local injson = cjson.encode(json_body)
        ok = g_redis.redis_set(red, msgid, injson)
    end
    g_redis.close_db(red)

    return ok
end

function time_rule_status.del(msgid)
    local red
    red = g_redis.open_db(red)
    msgid = 'tstatus'..string.sub(msgid, 6)
    local ok = g_redis.redis_del(red, msgid)
    g_redis.close_db(red)
end

--从redis获取ResultUpload
function time_rule_status.check_result_upload(msg_id)
    local result, cmd_status = time_rule_status.query(msg_id)
    --ngx.log(ngx.DEBUG,"query redis: ", result, cmd_status)
    if result == nil then
        return nil, ""
    end

    local result_table = cjson.decode(result)

    if result_table["MsgId"] ~= msg_id then
        ngx.log(ngx.ERR,"MsgId "..result_table["MsgId"].." not match")
        return nil, ""
    end
    
    if result_table["Payload"] ~= nil then
        local payload = result_table["Payload"]
        if payload["Result"] ~= nil then
            ngx.log(ngx.INFO,"method result upload: ", payload["Result"], payload["Descrip"])
            return payload["Result"], cmd_status
        end
    end

    if cmd_status == "Timeout" then
        return 4, cmd_status
    end

    return nil, cmd_status
end

return time_rule_status