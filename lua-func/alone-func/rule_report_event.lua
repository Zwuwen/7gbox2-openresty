local m_report_event = {}

--load module
local g_rule_common = require("alone-func.rule_common")
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")


--function define
--
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
    local uri = "http://127.0.0.1:8080/v0001/event"
    local http_str = encode_rule_exec_report(msgid,errcode, desp, data_table)


    g_rule_common.request_http("POST", uri, http_str)
end



return m_report_event