--const define
local uri_len = 16
local rule_pre_index = 1
local rule_post_index = 16

--load module
local cjson = require("cjson")


--------------------------------main function----------------------------
--check uri
local request_method = ngx.var.request_method
if request_method ~= "GET"  then
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"method no support\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	ngx.flush()
	return
end

local uri = ngx.var.uri
local uri_sub = string.sub(uri,rule_pre_index,rule_post_index)
if uri_sub ~= "/v0001/heartbeat" then
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"uri prefix is error\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	ngx.flush()
	return
end

if #uri ~= uri_len then
	local json_str = '{\n\"errcode\":400,\n \"msg\":\"uri len is error\",\n\"payload\":{}\n}'
	ngx.say(json_str)
	ngx.flush()
	return
end

--exec
if request_method == "GET" then
	local json_str = '{\n\"status\":\"ok\"\n}'
	ngx.say(json_str)
	ngx.flush()
end