--从postgres 查询数据，并以JSON的格式展示
--local res = ngx.location.capture('/postgres',{ args = {sql = "insert into run_rule_tbl (rule_uuid,priority,status,opcode,opcode_param,start_time,end_time,effective_time,invalid_time) values ('9001-00001',1,1,123,'value = 80','20190101','20190102','20190101','20190103')"}})
local json = require "cjson"

ngx.log(ngx.ERR,"###############lua test module#################")
--function test()
	local res = ngx.location.capture('/postgres',{ args = {sql = "select * from run_rule_tbl"}})

    local status = res.status
    local body = json.decode(res.body)

    len = string.format("len:%d",table.getn(body))

    ngx.log(ngx.ERR,len)	
    for k,v in ipairs(body) do
	ngx.log(ngx.ERR,string.format("%s",k))
    end	    
    if status == 200 then
        status = true
    else
        status = false
    end
    return status, body
--end

--test()
