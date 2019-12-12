local screen_rule = {} 

-- 常量


--导入模块
local g_micro = require("cmd-func.cmd_micro")

-- 函数
function screen_rule.screen_request_http(dev_type, rule_param)
    local res, err = g_micro.micro_post(dev_type,rule_param)
    if err == false then
        ngx.log(ngx.ERR,"screen service err: ",res)
        return false
    end
end
 

return screen_rule