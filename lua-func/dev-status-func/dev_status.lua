local dev_status_M = {version='v1.0.1'}
local cjson = require("cjson")
local g_redis = require("common.redis.g_redis_M")

function dev_status_M.set_temp_cmd_data(cmd_data)
    local json_body = cjson.decode(cmd_data)
    local key_str = json_body["MsgId"]
    local value_str = cjson.encode(json_body)
    g_redis.open_db()
    local ok = g_redis.redis_set(key_str,value_str)
    g_redis.close_db()
    return ok
end

function dev_status_M.set_ack_cmd_data(msg_id)
    g_redis.open_db()
    local res = g_redis.redis_get(msg_id)
    if res ~= nil then
        local json_body = cjson.decode(res)
        ngx.update_time()
        json_body["TimeStamp"] = ngx.now()
        local key_str = string.format("%s-%s-%s",json_body["DevId"],json_body["DevChannel"],json_body["Method"])
        local value_str = cjson.encode(json_body)
        local ok = g_redis.redis_set(key_str,value_str)
        ok = g_redis.redis_del(msg_id)
    end
    g_redis.close_db()
end

function dev_status_M.get_real_cmd_data(key)
    g_redis.open_db()
    local res = g_redis.redis_get(key)
    g_redis.close_db()
    return res
end

function dev_status_M.get_keys(pattery)
    g_redis.open_db()
    local res = g_redis.redis_get_keys(pattery)
    g_redis.close_db()
    return res
end

return dev_status_M