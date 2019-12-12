--http module
local myhttp_M = {version='v1.0.1'}

local http_module = nil 
local http = nil

function myhttp_M.init()
	http_module = require("thirdlib.http")
	http = http_module.new()
end

function myhttp_M.uninit()
	if http ~= nil then
		local rt = http:close()
	end
	
	http = nil
	http_module = nil
end

function myhttp_M.request_url(url,method_str,body_str)
	local res,err = http:request_uri(url,{
		method = method_str,
		body = body_str,
		headers = {["Content-Type"] = "application/json"},
		keepalive_timeout = 60,
		keepalive_pool = 10
	})

	if not res then
		return '{\n\"errcode\":404,\n \"msg\":\"no response\"\n\"payload\":{}\n}',false
	else
		return res.body,true
	end
end

return myhttp_M
