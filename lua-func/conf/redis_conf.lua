local M_redis_conf = {}

--host
M_redis_conf.host = "127.0.0.1"
--port
M_redis_conf.port = 6379
--connect pool number
M_redis_conf.max_pool = 50
--timeout  ms
M_redis_conf.timeout = 1000
--max free time ms
M_redis_conf.free_time = 10000

return M_redis_conf