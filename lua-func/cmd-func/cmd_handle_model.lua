--alone function
--restful parsing parameters
--version/rule/rule_uuid
--load module
local g_sql_app = require("common.sql.g_orm_info_M")
local cjson = require("cjson")
local g_micro = require("cmd-func.cmd_micro")
local g_event_report = require("event-func.event_report")
local g_cmd_sync = require("rule-func.cmd_sync")
local g_http = require("common.http.myhttp_M")
local g_linkage = require("rule-func.linkage_sync")

local timer_dev_timer_method = {};
local lamp_timer_method = {"SetOnOff", "SetBrightness"}
local info_screen_timer_method = {"SetOnOff", "LoadProgram", "SetBrightness", "SetVolume"}
local ipc_onvif_timer_method = {"GotoPreset"}
local speaker_timer_method = {"PlayProgram"}
timer_dev_timer_method["Lamp"] = lamp_timer_method
timer_dev_timer_method["InfoScreen"] = info_screen_timer_method
timer_dev_timer_method["IPC-Onvif"] = ipc_onvif_timer_method
timer_dev_timer_method["Speaker"] = speaker_timer_method

local m_cmd_handle = {}
local g_cmd_handle_body_table = {}
local g_is_cmd_handle_timer_running = false
local g_cmd_handle_body_table_locker = false

local g_platform_linkage_restore_table = {}
local g_is_platform_linkage_restore_timer_running = false
local g_platform_linkage_restore_locker = false
local g_platform_linkage_restore_timer_start = false
-----------------cmd update method-----------------
local function creat_respone_message(result, descrip)
	local payload={}
	payload["Result"] = result
	payload["Descrip"] = descrip
	local message={}
	message["Payload"] = payload
	
	return cjson.encode(message)
end

local function result_message_pack(json_body,res)
	if json_body["MsgId"]~=nil then
		local url = "http://127.0.0.1:8080/v0001/event"
		local return_json = cjson.decode(res)
		return_json["MsgId"] = json_body["MsgId"]
		return_json["Event"] = "ResultUpload"
		local res_str = cjson.encode(return_json)
		g_http.init()
		g_http.request_url(url,"POST",res_str)
		g_http.uninit()
	end
end

local function attribute_change_message(dev_type,dev_id,channel_id,status)
	local json_dict = {}
	json_dict["Token"] = "7GBox"
	json_dict["Event"] = "StatusUpload"
	local dev_dict = {}
	dev_dict["DevType"] = dev_type
	dev_dict["DevId"] = dev_id
	local attr = {}
	attr["AutoMode"] = status
	dev_dict["Attributes"] = attr
	local dev_list = {dev_dict}
	local payload = {}
	payload["Devices"] = dev_list
	json_dict["Payload"] = payload
	return json_dict
end

local function remove_table(base, remove)
    local new_table = {}
    for k, v in ipairs(base) do
        local find_key = false
        for rk, rv in ipairs(remove) do
            if rv == k then
                find_key = true
                break
            end
        end
        if not find_key then
            table.insert(new_table, v)
        end
    end
    return new_table
end

local function is_timer_method(dev_type, method_name)
	if timer_dev_timer_method[dev_type] ~= nil then
		local method_table = timer_dev_timer_method[dev_type]
		for i = 1, #method_table do
			if method_table[i] == method_name then
				return true
			end
		end
	end
	return false
end

local function linkage_restore_timer_body()
	if g_is_platform_linkage_restore_timer_running == false then
		g_is_platform_linkage_restore_timer_running = true
		local want_remove = {}
		for k,v in ipairs(g_platform_linkage_restore_table) do
			ngx.update_time()
			if tonumber(ngx.now()) >= v[2] then
				--当前时间大于结束时间，结束策略联动，恢复联动前状态，并从table中删除
				local linkage_end_dev = {}
				linkage_end_dev[1] = v[1]
				local data = cjson.encode(linkage_end_dev)
				ngx.log(ngx.INFO,"linkage end param: ", data)
				g_event_report.linkage_end(linkage_end_dev)
				--ngx.timer.at(0, g_event_report.linkage_end, data)
				table.insert(want_remove, k)
			end
		end

		while true do
			if not g_platform_linkage_restore_locker then
				g_platform_linkage_restore_locker = true
				if next(want_remove)~= nil then
					g_platform_linkage_restore_table = remove_table(g_platform_linkage_restore_table, want_remove)
				end
				
				if next(g_platform_linkage_restore_table) ~= nil then
					ngx.timer.at(1, linkage_restore_timer_body)
					ngx.log(ngx.INFO,"start new timer")
				else
					g_platform_linkage_restore_timer_start = false
					ngx.log(ngx.INFO,"g_platform_linkage_restore_table is empty")
				end
				g_platform_linkage_restore_locker = false
				break
			else
				ngx.sleep(0.01)
			end
		end

		g_is_platform_linkage_restore_timer_running = false
	end
end

-----------------cmd post method---------------------
local function create_method(request_body)

end

-----------------cmd delete method-----------------
local function delete_method(request_body)

end

local function get_method(request_body)
	local json_body = cjson.decode(request_body)
end


local function update_method(request_body)
	local json_body = cjson.decode(request_body)
	ngx.log(ngx.DEBUG,"cmd put, msgid: ", json_body["MsgId"])

	if (json_body["DevType"]==nil or json_body["DevId"]==nil or json_body["DevChannel"]==nil or json_body["Method"]==nil)
	and json_body["Method"] ~= "CancelLinkageRule" then
		local res = creat_respone_message(2, "Parameter error")
		result_message_pack(json_body, res)
		return
	end


	local result = nil
	if json_body["Method"] ~= "CancelLinkageRule" then
		result = g_sql_app.query_dev_status_tbl(json_body["DevId"])
		if result[1] ~= nil then
			if (result[1]["online"] == 0 and json_body["Method"] ~= "CancelLinkageRule") then
				local res = creat_respone_message(15, "Device offline")
				result_message_pack(json_body, res)
				return
			end
		else
			local res = creat_respone_message(1, "Query device status failed")
			result_message_pack(json_body, res)
			return
		end
	end

	if json_body["Method"] == "Linkage" then
		--平台触发联动的动作
		local control_list = json_body["In"]["Control"]
		local dev_type = json_body["DevType"]
		local dev_id = json_body["DevId"]
		local dev_channel = json_body["DevChannel"]
		local level = json_body["In"]["Level"]
		
		while true do
			if not g_platform_linkage_restore_locker then
				g_platform_linkage_restore_locker = true

				for k,v in ipairs(g_platform_linkage_restore_table) do
					--如果联动等级低于正在执行的等级，忽略
					if v[1] == dev_id and level > v[3] then
						local res = creat_respone_message(1, "high level linkage is running")
						result_message_pack(json_body,res)
						g_platform_linkage_restore_locker = false
						return
					end
				end
				--修改该设备的联动状态为2（平台联动）
				local update_json = {}
				update_json["linkage_rule"] = 2
				update_json["online"] = 1
				g_sql_app.update_dev_status_tbl(dev_id,update_json)
				g_linkage.linkage_start_stop_rule(nil,dev_id,1)
				--遍历联动控制的动作列表，下发命令至微服务
				for k,v in ipairs(control_list) do
					local request_json = {}
					request_json["Token"] = "PlatformLinkage"
					request_json["DevType"] = dev_type
					request_json["DevId"] = dev_id
					request_json["DevChannel"] = dev_channel
					request_json["Method"] = v["Method"]
					request_json["In"] = v["In"]
					local request_string = cjson.encode(request_json)
					ngx.log(ngx.INFO,"platform linkage post to micro server: ", request_string)
					local res,status = g_micro.micro_post(dev_type, request_string)
				end
				--将设备id，联动结束时间，联动等级记录到table中，由定时器进行判断
				ngx.update_time()
				local end_time = tonumber(json_body["In"]["Time"]) + tonumber(ngx.now())
				local restore_info_table = {dev_id, end_time, level}
				local running = false
				--如果已经有存在的对应设备id的节点，那么直接修改响应的策略结束时间和策略等级
				for k,v in ipairs(g_platform_linkage_restore_table) do
					if v[1] == dev_id then
						v[2] = end_time
						v[3] = level
						running = true
						break
					end
				end
				--如果没有存在对应的设备id的节点，那么插入一个新节点
				if running == false then
					table.insert(g_platform_linkage_restore_table, restore_info_table)
				end
				if g_platform_linkage_restore_timer_start == false then
					g_platform_linkage_restore_timer_start = true
					ngx.timer.at(1, linkage_restore_timer_body)
				end
				g_platform_linkage_restore_locker = false
				break
			else
				ngx.sleep(0.05)
			end
		end
		local res = creat_respone_message(0, "Success")
		result_message_pack(json_body,res)
	elseif json_body["Method"] == "ResetToAuto" then
		if result[1]["auto_mode"] == 1 then
			local res = creat_respone_message(0, "Success")
			result_message_pack(json_body,res)
			return
		end
		--命令切换自动
		local update_json = {}
		update_json["auto_mode"] = 1
		result = g_sql_app.query_dev_info_tbl(json_body["DevId"])
		if result[1]["dev_type"] == json_body["DevType"] then
			g_sql_app.update_dev_status_tbl(json_body["DevId"],update_json)
			
			g_cmd_sync.cmd_start_stop_rule(json_body["DevType"],json_body["DevId"], 0)
			local res = creat_respone_message(0,"Success")
			result_message_pack(json_body,res)
			local message = attribute_change_message(json_body["DevType"],json_body["DevId"],json_body["DevChannel"],1)
			g_event_report.attribute_change(message)
		else
			local res = creat_respone_message(1,"Fail")
			result_message_pack(json_body,res)
		end
	elseif json_body["Method"] == "ResetToManual" then
		if result[1]["auto_mode"] == 0 then
			local res = creat_respone_message(0, "Success")
			result_message_pack(json_body,res)
			return
		end
		--命令切换手动
		local update_json = {}
		update_json["auto_mode"] = 0
		result = g_sql_app.query_dev_info_tbl(json_body["DevId"])
		if result[1]["dev_type"] == json_body["DevType"] then
			g_sql_app.update_dev_status_tbl(json_body["DevId"],update_json)
			g_cmd_sync.cmd_start_stop_rule(json_body["DevType"],json_body["DevId"], 1)
			local res = creat_respone_message(0,"Success")
			result_message_pack(json_body,res)
			local message = attribute_change_message(json_body["DevType"],json_body["DevId"],json_body["DevChannel"],0)
			g_event_report.attribute_change(message)
		else
			local res = creat_respone_message(1,"Fail")
			result_message_pack(json_body,res)
		end
	elseif json_body["Method"] == "CancelLinkageRule" then
		local res,status = g_micro.micro_delete("RuleEngine",request_body)
		result_message_pack(json_body,res)
	else
		--查询是否处于自动或者联动
		result = g_sql_app.query_dev_status_tbl(json_body["DevId"])
		if result[1] ~= nil then
			if (result[1]["auto_mode"] == 0 or is_timer_method(json_body["DevType"], json_body["Method"]) == false) and result[1]["linkage_rule"] == 0 then
				--转发命令到微服务
				local res,status = g_micro.micro_post(json_body["DevType"],request_body)
				if status == false then
					local return_json = cjson.decode(res)
					local res = creat_respone_message(return_json["Payload"]["Result"], return_json["Payload"]["Descrip"])
					result_message_pack(json_body,res)
				else
					local return_json = cjson.decode(res)
					if return_json["Payload"]["Result"] ~= 0 then
						ngx.log(ngx.DEBUG,"micro post return true, but result not 0, return: ", res)
						local res = creat_respone_message(return_json["Payload"]["Result"], return_json["Payload"]["Descrip"])
						result_message_pack(json_body, res)
					end
				end
			else
				local res = creat_respone_message(3, "device is auto mode")
				result_message_pack(json_body,res)
			end
		else
			local res = creat_respone_message(2, "DevId error")
			result_message_pack(json_body,res)
		end
	end
	ngx.log(ngx.DEBUG,"cmd put end, msgid: ", json_body["MsgId"])
end

function m_cmd_handle.add_handle(request_method, request_body)
	local request_table = {request_method, request_body}
	while true do
		if not g_cmd_handle_body_table_locker then
            g_cmd_handle_body_table_locker = true
            table.insert(g_cmd_handle_body_table, request_table)
            g_cmd_handle_body_table_locker = false
            break
        else
            ngx.sleep(0.01)
		end
	end
end

function m_cmd_handle.cmd_handle_thread()
	if g_is_cmd_handle_timer_running == false then
		g_is_cmd_handle_timer_running = true
		local want_remove = {}
		for k, v in ipairs(g_cmd_handle_body_table) do
			local request_method = v[1]
			if request_method == "PUT" then
				update_method(v[2])
			elseif request_method == "GET" then
				get_method(v[2])
			elseif request_method == "POST" then
				create_method(v[2])
			elseif request_method == "DELETE" then
				delete_method(v[2])
			end
			table.insert(want_remove, k)
		end
		---remove table what has been handle
        if next(want_remove)~= nil then
            while true do
                if not g_cmd_handle_body_table_locker then
                    g_cmd_handle_body_table_locker = true
                    g_cmd_handle_body_table = remove_table(g_cmd_handle_body_table, want_remove)
                    g_cmd_handle_body_table_locker = false
                    break
                else
                    ngx.sleep(0.01)
                end
            end
        end
		g_is_cmd_handle_timer_running = false
	end
end


return m_cmd_handle