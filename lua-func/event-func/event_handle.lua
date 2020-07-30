--eventfunction
--restful parsing parameters

--const define

--load module
local cjson = require("cjson")
local g_mydef = require("common.mydef.mydef_func")
local g_event_handle = require("event-func.event_handle_model")
local g_sql_app = require("common.sql.g_orm_info_M")


local function event_error_handle(err)
	ngx.log(ngx.ERR,"event_error_handle ERR: ", err)
end

local function event_handle()
    local request_method = ngx.var.request_method
    ngx.req.read_body()
    local request_body = ngx.req.get_body_data()
    ngx.log(ngx.DEBUG,"recv event: ",request_method, request_body)

    g_event_handle.add_handle(request_method, request_body)

    local json_str = '{\n\"Code\":200,\n \"Msg\":\"Sucess"\n\"Payload\":{}\n}'
    ngx.say(json_str)
    ngx.flush()
end
-------main function------------
local status = xpcall(event_handle, event_error_handle)
