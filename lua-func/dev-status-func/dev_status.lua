local dev_status_M = {version='v1.0.1'}
local cjson = require("cjson")
local g_redis = require("common.redis.g_redis_M")

function dev_status_M.set_temp_cmd_data(cmd_data)
    local json_body = cjson.decode(cmd_data)
    local key_str = json_body["MsgId"]
    local value_str = cjson.encode(json_body)
    local red
    red = g_redis.open_db(red)
    local ok = g_redis.redis_set(red,key_str,value_str)
    g_redis.close_db(red)
    return ok
end

function dev_status_M.set_ack_cmd_data(msg_id)
    local red
    red = g_redis.open_db(red)
    local res = g_redis.redis_get(red,msg_id)
    if res ~= nil then
        local json_body = cjson.decode(res)
        ngx.update_time()
        json_body["TimeStamp"] = ngx.now()
        local key_str = string.format("%s-%s-%s",json_body["DevId"],json_body["DevChannel"],json_body["Method"])
        local value_str = cjson.encode(json_body)
        local ok = g_redis.redis_set(red,key_str,value_str)
    end
    g_redis.close_db(red)
end

function dev_status_M.get_real_cmd_data(key)
    local red
    red = g_redis.open_db(red)
    local res = g_redis.redis_get(red,key)
    g_redis.close_db(red)
    return res
end

function dev_status_M.get_keys(pattery)
    local red
    red = g_redis.open_db(red)
    local res = g_redis.redis_get_keys(red,pattery)
    g_redis.close_db(red)
    return res
end

function dev_status_M.del_control_method(msg_id)
    local red
    red = g_redis.open_db(red)
    local ok = g_redis.redis_del(red,msg_id)
    g_redis.close_db(red)
end

return dev_status_M