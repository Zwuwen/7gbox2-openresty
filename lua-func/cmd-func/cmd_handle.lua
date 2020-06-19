local cjson = require("cjson")
local g_cmd_handle_model = require("cmd-func.cmd_handle_model")

local function creat_respone_message(result, descrip)
	local payload={}
	payload["Result"] = result
	payload["Descrip"] = descrip
	local message={}
	message["Payload"] = payload
	
	return cjson.encode(message)
end

local function message_pack(json_body,res)
	if json_body["MsgId"]~=nil then
		local return_json = cjson.decode(res)
		return_json["MsgId"] = json_body["MsgId"]
		local gw = g_sql_app.query_dev_info_tbl(0)
		if gw ~= nil and gw[1] ~=nil then
			return_json["GW"] = gw[1]["sn"]
		end
		return_json["Event"] = "ReqStsUpload"
		local res_str = cjson.encode(return_json)
		ngx.say(res_str)
	else
		ngx.say(res)
	end
	ngx.flush()
end


local function request_error_handle(err)
	ngx.log(ngx.ERR,"request_error_handle ERR: ", err)
end

local function request_cmd_handle(request_method)
	ngx.req.read_body()
	local request_body = ngx.req.get_body_data()
	g_cmd_handle_model.add_handle(request_method, request_body)
	local res = creat_respone_message(0, "Success")

	local json_body = cjson.decode(request_body)
	message_pack(json_body, res)
end
-------main function------------

local request_method = ngx.var.request_method
status = xpcall( request_cmd_handle, request_error_handle, request_method )

