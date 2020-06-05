local m_report_event = {}

--load module
local g_rule_common = require("alone-func.rule_common")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_sql_app = require("common.sql.g_orm_info_M")

local uri = "http://127.0.0.1:8080/v0001/event"

--function define
--数据库增删改查上报报文
local function encode_rule_exec_report(msgid,errcode, desp, data_table)
	local f_table = {}
	local f_str = ''
	
    f_table["Token"] = "7GBox"
    f_table["Event"] = "ResultUpload"
    --f_table["GW"] = ""
    f_table["MsgId"] = msgid
    
    local payload = {}
	payload["Result"] = errcode
	payload["Descrip"] = desp
    payload["Out"] = data_table
    f_table["Payload"] = payload
	
	f_str = cjson.encode(f_table)
	ngx.log(ngx.INFO," ", f_str)
	return f_str
end

--
function m_report_event.report_status(msgid,errcode, desp, data_table)
    local http_str = encode_rule_exec_report(msgid,errcode, desp, data_table)

    g_rule_common.request_http("POST", uri, http_str)
end

--策略执行上报报文
local function encode_rule_exec_status(rule,status,cnt,errcode,descrip)
	local f_table = {}
    local f_str = ''

    local gw = g_sql_app.query_dev_info_tbl(0)
    local actions = cjson.decode(rule["actions"])
    ngx.update_time()
	
    f_table["Token"] = "7GBox"
    f_table["Event"] = "TimerRuleStatus"
    f_table["GW"] = gw[1]["sn"]
    f_table["Time"] = tostring((ngx.now() * 1000))
    
    local payload = {}
    payload["Status"] = status      --Start/End
    payload["RuleUuid"] = rule["rule_uuid"]
    payload["DevType"] = rule["dev_type"]
    payload["DevId"] = rule["dev_id"]
    payload["DevChannel"] = rule["dev_channel"]
    payload["Actions"] = actions

    if status == "Start" then
        for i,action in ipairs(payload["Actions"]) do
            if i < cnt then
                action["ResultCode"] = 0
                action["ResultDescrip"] = "Success"
            elseif i == cnt then
                action["ResultCode"] = errcode
                action["ResultDescrip"] = descrip
            elseif i > cnt then
                action["ResultCode"] = 12
                action["ResultDescrip"] = "Not Execute"
            end
        end
    end

    f_table["Payload"] = payload
	
	f_str = cjson.encode(f_table)
	--ngx.log(ngx.INFO," ", f_str)
	return f_str
end

function m_report_event.report_rule_exec_status(rule,status,cnt,errcode,descrip)
    local http_str = encode_rule_exec_status(rule,status,cnt,errcode,descrip)

    g_rule_common.request_http("POST", uri, http_str)
end

return m_report_event