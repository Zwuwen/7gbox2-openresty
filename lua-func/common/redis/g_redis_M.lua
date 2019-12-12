local g_redis_M = {version='v1.0.1'}

--local define

local red
--open redis
function g_redis_M.open_db()
    local redis_conf = require "conf.redis_conf"
    local redis = require "thirdlib.redis"
    redis.add_commands("keys")
    red = redis:new()
    red:set_timeout(redis_conf.timeout)
    local ok,err = red:connect(redis_conf.host,redis_conf.port)
    if not ok then
        ngx.log(ngx.ERR,"connect redis db fail")
        return false
    end
    if not ok then
        ngx.log(ngx.ERR,"redis db fail to set_keepalive")
        return false
    end
    ngx.log(ngx.ERR,"connect redis db success!")
    return true
end

--close db
function g_redis_M.close_db()
    red:close()
    ngx.log(ngx.ERR,"redis db close!")
end

--set sing data
function g_redis_M.redis_set(key,value)
    local ok,err = red:set(key,value)
    if not ok then
        ngx.log(ngx.ERR,"redis_set is fail!")
        return false
    end
    return true
end

--get sing data
function g_redis_M.redis_get(key)
    local res,err = red:get(key)
    if  res == ngx.null then
        ngx.log(ngx.ERR,"redis_get is fail!")
        return nil
    end
    return res
 end

 --del
 function g_redis_M.redis_del(key)
    local res,err = red:del(key)
    if not res then
        ngx.log(ngx.ERR,"redis_del is fail!")
        return false
    end
    return true
 end

 function g_redis_M.redis_get_keys(pattern)
    local res,err = red:keys(pattern)
    if not res then
        ngx.log(ngx.ERR,"redis_del is fail!")
        return nil
    end
    return res
 end

 return g_redis_M