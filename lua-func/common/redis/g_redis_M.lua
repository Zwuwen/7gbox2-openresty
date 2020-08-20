local g_redis_M = {version='v1.0.1'}

--local define

--open redis
function g_redis_M.open_db(red)
    local redis_conf = require "conf.redis_conf"
    local redis = require "thirdlib.redis"
    redis.add_commands("keys")
    red = redis:new()
    red:set_timeout(redis_conf.timeout)
    local ok,err = red:connect(redis_conf.host,redis_conf.port)
    if not ok then
        ngx.log(ngx.ERR,"connect redis db fail, err: ", err)
        return nil
    end
    --ngx.log(ngx.ERR,"connect redis db success!")
    return red
end

--close db
function g_redis_M.close_db(red)
    if red ~= nil then
        red:close()
    end
    --red = nil
    --ngx.log(ngx.ERR,"redis db close!")
end

--set sing data
function g_redis_M.redis_set(red,key,value)
    if red ~= nil then
        for var=0,10,1 do
            local ok,err = red:set(key,value)
            if ok then
                return true
            end
            ngx.sleep(0.1)
        end
    end
    str_log = string.format("redis_set is fail! key:%s, value:%s ",key, value)
    ngx.log(ngx.ERR, str_log)
    return false
end

--get sing data
function g_redis_M.redis_get(red,key)
    if red ~= nil then
        for var=0,10,1 do
            local res,err = red:get(key)
            if  res ~= ngx.null then
                return res
            end
            ngx.sleep(0.1)
        end
    end
    ngx.log(ngx.ERR,"redis_get is fail! key: ", key)
    return nil
 end

--del
function g_redis_M.redis_del(red,key)
    if red ~= nil then
        for var=0,10,1 do
            local res,err = red:del(key)
            if res then
                return true
            end
            ngx.sleep(0.1)
        end
    end
    ngx.log(ngx.ERR,"redis_del is fail!")
    return false
end

function g_redis_M.redis_get_keys(red,pattern)
    if red ~= nil then
        for var=0,10,1 do
            local res,err = red:keys(pattern)
            if res then
                return res
            end
            ngx.sleep(0.1)
        end
    end
    ngx.log(ngx.ERR,"redis_del is fail!")
    return nil
end

return g_redis_M