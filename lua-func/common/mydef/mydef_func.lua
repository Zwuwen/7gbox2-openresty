local mydef_M = {version='v1.0.1'}

--table lenght
function mydef_M.table_len(input_table)
	local count = 0
	print(type(input_table))
	if type(input_table) ~= 'table' then
		return -1,0
	end

	for k,v in pairs(input_table) do
		count = count + 1
	end
	return count,nil
end

--errcode msg show
function mydef_M.show_errinfo(msg,errcode,payload)
	local json_str = string.format('{\n\"errcode\":%d,\n \"msg\":\"%s\"\n\"payload\":{\"%s\"}\n}',errcode,msg,payload)
	ngx.say(json_str)
end

function mydef_M.trim(s)
return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

mydef_M.err_code = {
	QJ_ERR_CODE_SUB = 0,
	QJ_ERR_CODE_UNKOWN = 1
}

return mydef_M
