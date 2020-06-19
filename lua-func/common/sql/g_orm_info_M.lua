--data pojo module
local g_orm_info_M = {version='v1.0.1'}
--local define
local sql_conf = nil
local postgres = nil
local cjson = require("cjson")
local db = nil

--open db
function g_orm_info_M.open_db()
	sql_conf = require("conf.sql_conf")
	postgres = require("thirdlib."..sql_conf.sql)
	local conn_str = string.format("host=%s dbname=%s user=%s password=%s",sql_conf.host,sql_conf.database,sql_conf.user,sql_conf.password)
	ngx.log(ngx.ERR,"connect str:",conn_str)

	local err = nil
	db,err = postgres:connect(conn_str)
	if err then
		ngx.log(ngx.ERR,"connect failure:"..err)
		return false
	end
	local version,err = db:version()
	if err then
		ngx.log(ngx.ERR,"query version:"..err)
		return false
	end
	ngx.log(ngx.ERR,"postgres version:"..cjson.encode(version))

	ngx.log(ngx.ERR,"connect db sucess")

	return true
end

--close db
function g_orm_info_M.close_db()
	if db == nil then
		ngx.log(ngx.ERR,"close db complete")
		return
	end
	ngx.log(ngx.ERR,"###########close db sucess")
	db:close()
	db = nil
end


-------------------micro_svr_tbl----- micro service table------------------------
--"dev_type"
--"dev_type_ex"
--"url_prefix"
--"online"
function g_orm_info_M.insert_micro_svr_tbl(json)
	if json["dev_type_ex"] ~= nil then
		local value_str = string.format("(\'%s\',\'%s\',\'%s\',%d)", json["dev_type"], json["dev_type_ex"], json["url_prefix"], json["online"])
		local res,err = db:execute("insert into micro_svr_tbl (dev_type, dev_type_ex, url_prefix, online) values "..value_str)
	else
		local value_str = string.format("(\'%s\',\'%s\',%d)", json["dev_type"], json["url_prefix"], json["online"])
		local res,err = db:execute("insert into micro_svr_tbl (dev_type, url_prefix, online) values "..value_str)
	end
	return res,err
end

--"url_prefix"
--"online"
function g_orm_info_M.update_micro_svr_tbl(dev_type, json)
	local sql_str = string.format("update micro_svr_tbl set")
	if json["online"] ~= nil then
		local online_int = json["online"]
		if online_int ~= 0 then
			online_int = 1
		end
		sql_str = string.format( "%s online=%d,", sql_str, online_int)
	end

	if json["url_prefix"] ~= nil then
		sql_str = string.format( "%s url_prefix=\'%s\',", sql_str, json["url_prefix"])
	end

	sql_str = string.format( "%s where dev_type=\'%s\'", sql_str, dev_type)
	sql_str = string.gsub(sql_str, ', where', ' where', 1)
	ngx.log(ngx.ERR," ", sql_str)

	local res,err = db:execute(sql_str)
	return res,err
end

function g_orm_info_M.query_micro_svr_tbl(dev_type)
	local sql_str = string.format("select * from micro_svr_tbl where dev_type=\'%s\'",dev_type)
	local res,err = db:query(sql_str)
	return res,err
end

function g_orm_info_M.query_micro_svr_all()
	local sql_str = string.format("select * from micro_svr_tbl")
	local res,err = db:query(sql_str)
	return res,err
end
-------------------dev_status_tbl------device status table------------------------
--
--输入类型：table
function g_orm_info_M.insert_dev_status_tbl(json)
	if json["online"]==nil or json["dev_id"]==nil then
		ngx.log(ngx.ERR, "return err\n")
		return "param error", false
	end

	local online_int = 0
	if json["online"] > 0 then
		online_int = 1
	end

	local sql_str = string.format("insert INTO dev_status_tbl (dev_id, online,")
	
	if json["attribute"] ~= nil then
		sql_str = string.format( "%s attribute,", sql_str)
	end

	if json["last_online_time"] ~= nil then
		sql_str = string.format( "%s last_online_time,", sql_str)
	end

	sql_str = string.format( "%s replace1 values (%d, %d,", sql_str, json["dev_id"], online_int)
	sql_str = string.gsub(sql_str, ", replace1 values", ") values", 1)

	if json["attribute"] ~= nil then
		local attr_str = cjson.encode(json["attribute"])
		sql_str = string.format( "%s \'%s\',", sql_str, attr_str)
	end

	if json["last_online_time"] ~= nil then
		sql_str = string.format( "%s \'%s\',", sql_str, json["last_online_time"])
	end

	sql_str = string.format( "%s replace2", sql_str)
	sql_str = string.gsub(sql_str, ', replace2', ')', 1)
	ngx.log(ngx.ERR," ", sql_str)

	local res,err = db:execute(sql_str)
	return res,err
end

--
--输入类型：int, table
function g_orm_info_M.update_dev_status_tbl(dev_id, json)
	if dev_id==nil then
		return "param error", false
	end

	local sql_str = string.format("update dev_status_tbl set")
	
	if json["online"] ~= nil then
		local online_int = json["online"]
		if online_int ~= 0 then
			online_int = 1
		end
		sql_str = string.format( "%s online=%d,", sql_str, online_int)
	end

	if json["attribute"] ~= nil then
		local attr_str = cjson.encode(json["attribute"])
		sql_str = string.format( "%s attribute=\'%s\',", sql_str, attr_str)
	end

	if json["last_online_time"] ~= nil then
		sql_str = string.format( "%s last_online_time=\'%s\',", sql_str, json["last_online_time"])
	end

	if json["auto_mode"] ~= nil then
		sql_str = string.format( "%s auto_mode=%d,", sql_str, json["auto_mode"])
	end

	if json["linkage_rule"] ~= nil then
		sql_str = string.format( "%s linkage_rule=%d,", sql_str, json["linkage_rule"])
	end

	sql_str = string.format( "%s where dev_id=%d", sql_str, dev_id)
	sql_str = string.gsub(sql_str, ', where', ' where', 1)
	ngx.log(ngx.ERR," ", sql_str)

	local res,err = db:execute(sql_str)
	return res,err
end

function g_orm_info_M.query_dev_status_tbl(dev_id)
	local sql_str = string.format("select * from dev_status_tbl where dev_id=%d",dev_id)
	local res,err = db:query(sql_str)
	return res,err
end

-------------------dev_info_tbl------device info table--------can't be update----------------
function g_orm_info_M.insert_dev_info_tbl(json)
	local value_str = string.format("(%d,%s,%d,%d,\'%s\',\'%s\',\'%s\')", json["dev_id"], json["dev_type"], json["interface_type"], json["manufacturer_id"], json["sn"], json["ability_method"], json["ability_attribute"])
	local res,err = db:execute("insert into dev_info_tbl (dev_id, dev_type, interface_type, manufacturer_id, sn, ability_method, ability_attribute) values "..value_str)
	return res,err
end

function g_orm_info_M.query_dev_info_tbl(dev_id)
	local sql_str = string.format("select * from dev_info_tbl where dev_id=%d",dev_id)
	local res,err = db:query(sql_str)
	return res,err
end

function g_orm_info_M.query_dev_info_tbl_id(dev_type)
	local sql_str = string.format("select * from dev_info_tbl where dev_type=\'%s\'",dev_type)
	local res,err = db:query(sql_str)
	return res,err
end

function g_orm_info_M.query_all_dev_info_tbl()
	local sql_str = "select * from dev_info_tbl"
	local res,err = db:query(sql_str)
	return res,err
end
-------------------config_ip_tbl------config param of ip device--------
function g_orm_info_M.insert_config_ip_tbl(json)
	if json["dev_id"]==nil or json["ip"]==nil or json["port"]==nil then
		return "param error", false
	end

	local sql_str = string.format("insert INTO config_ip_tbl (dev_id, ip, port")
	
	if json["mac"] ~= nil then
		sql_str = string.format( "%s mac,", sql_str)
	end

	if json["usr"] ~= nil then
		sql_str = string.format( "%s usr,", sql_str)
	end

	if json["passwd"] ~= nil then
		sql_str = string.format( "%s passwd,", sql_str)
	end

	sql_str = string.format( "%s replace1 values (%d, %s, %d", sql_str, json["dev_id"], json["ip"], json["port"])
	sql_str = string.gsub(sql_str, ", replace1 values", ") values", 1)

	if json["mac"] ~= nil then
		sql_str = string.format( "%s \'%s\',", sql_str, json["mac"])
	end

	if json["usr"] ~= nil then
		sql_str = string.format( "%s \'%s\',", sql_str, json["usr"])
	end

	if json["passwd"] ~= nil then
		sql_str = string.format( "%s \'%s\',", sql_str, json["passwd"])
	end

	sql_str = string.format( "%s replace2", sql_str)
	sql_str = string.gsub(sql_str, ', replace2', ')', 1)
	ngx.log(ngx.ERR," ", sql_str)

	local res,err = db:execute(sql_str)
	return res,err
end

function g_orm_info_M.update_config_ip_tbl(dev_id, json)
	local sql_str = string.format("update config_ip_tbl set ")

	if json["ip"] ~= nil then
		sql_str = string.format( "%s ip=%s", sql_str, json["ip"])
	end

	if json["port"] ~= nil then
		sql_str = string.format( "%s port=%d", sql_str, json["port"])
	end

	if json["mac"] ~= nil then
		sql_str = string.format( "%s mac=%s", sql_str, json["mac"])
	end

	if json["usr"] ~= nil then
		sql_str = string.format( "%s usr=%s", sql_str, json["usr"])
	end

	if json["passwd"] ~= nil then
		sql_str = string.format( "%s passwd=%s", sql_str, json["passwd"])
	end

	sql_str = string.format( "%s where dev_id=%d", sql_str, dev_id)

	local res,err = db:execute(sql_str)
	return res,err
end

function g_orm_info_M.query_config_ip_tbl(dev_id)
	local sql_str = string.format("select * from config_ip_tbl where dev_id=%d",dev_id)
	local res,err = db:query(sql_str)
	return res,err
end

-------------------config_rs485_tbl------config param of ip device--------
function g_orm_info_M.insert_config_rs485_tbl(json)
	if 	json["dev_id"]==nil or
		json["port"]==nil or
		json["addr"]==nil or
		json["baund"]==nil or 
		json["parity"]==nil or
		json["stop"]==nil or
		json["data"]==nil 
		then
		return "param error", false
	end

	local value_str = string.format("(%d,%d,%s,%d,%d,%d,%d)", json["dev_id"], json["port"], json["addr"], json["baund"], json["parity"], json["stop"], json["data"])
	local res,err = db:execute("insert into config_rs485_tbl (dev_id, port, addr, baund, parity, stop, data) values "..value_str)
	return res,err
end

function g_orm_info_M.update_config_rs485_tbl(dev_id, json)
	local sql_str = string.format("update config_rs485_tbl set ")

	if json["port"] ~= nil then
		sql_str = string.format( "%s port=%d", sql_str, json["port"])
	end

	if json["addr"] ~= nil then
		sql_str = string.format( "%s addr=%s", sql_str, json["addr"])
	end

	if json["baund"] ~= nil then
		sql_str = string.format( "%s baund=%d", sql_str, json["baund"])
	end

	if json["parity"] ~= nil then
		sql_str = string.format( "%s parity=%d", sql_str, json["parity"])
	end

	if json["stop"] ~= nil then
		sql_str = string.format( "%s stop=%d", sql_str, json["stop"])
	end

	if json["data"] ~= nil then
		sql_str = string.format( "%s data=%d", sql_str, json["data"])
	end

	sql_str = string.format( "%s where dev_id=%d", sql_str, dev_id)

	local res,err = db:execute(sql_str)
	return res,err
end

function g_orm_info_M.query_config_rs485_tbl(dev_id)
	local sql_str = string.format("select * from config_rs485_tbl where dev_id=%d",dev_id)
	local res,err = db:query(sql_str)
	return res,err
end

-----------------------------------------------------rule table-todo------------------------------------------------------

--HTTP POST  插入一条策略
function g_orm_info_M.insert_rule_tbl(json)
	if 	json["RuleUuid"]==nil or
		json["DevType"]==nil or  
	  	json["DevId"]==nil or								  
		json["DevChannel"]==nil or
		json["Priority"]==nil or
		json["Actions"]==nil or
		json["StartTime"]==nil or
		json["EndTime"]==nil or
		json["StartDate"]==nil or
		json["EndDate"]==nil
		then
			ngx.log(ngx.ERR,"input param incomplete")
			return nil,"input param incomplete"
		end
	local actionsStr = cjson.encode(json["Actions"]);
	local value_str = string.format("(\'%s\',\'%s\',%d,%d,%d,\'%s\',\'%s\',\'%s\',\'%s\',\'%s\')",
									  json["RuleUuid"],
									  json["DevType"],  
					  				  json["DevId"],								  
									  json["DevChannel"],
									  json["Priority"],
									  actionsStr,
									  json["StartTime"],
									  json["EndTime"],
									  json["StartDate"],
									  json["EndDate"])
	local res,err = db:execute("insert into run_rule_tbl (rule_uuid,dev_type,dev_id,dev_channel,priority,actions,start_time,end_time,start_date,end_date) values "..value_str)
	return res,err
end

--HTTP DELETE  按rule_uuid删除一条策略
function g_orm_info_M.delete_rule_tbl_by_uuid(rule_uuid)
	local value_str = string.format("\'%s\'",rule_uuid)
	local res,err = db:execute("delete from run_rule_tbl where rule_uuid="..value_str)
	return res,err
end

--HTTP DELETE  删除一个设备的所有策略
function g_orm_info_M.delete_rule_tbl_by_dev_id(dev_type, dev_id)
	local dev_type_str = string.format("\'%s\'",dev_type)
	local dev_id_str = string.format("%d", dev_id)
	local res,err = db:execute("delete from run_rule_tbl where dev_type="..dev_type_str.." and dev_id="..dev_id_str)
	return res,err
end

--HTTP PUT  更新一条策略
function g_orm_info_M.update_rule_tbl(rule_uuid, json)
	local sql_str = string.format("update run_rule_tbl set")

	if json["DevType"] ~= nil then
		sql_str = string.format( "%s dev_type=\'%s\',", sql_str, json["DevType"])
	end

	if json["DevId"] ~= nil then
		sql_str = string.format( "%s dev_id=%d,", sql_str, json["DevId"])
	end

	if json["DevChannel"] ~= nil then
		sql_str = string.format( "%s dev_channel=%d,", sql_str, json["DevChannel"])
	end

	if json["Priority"] ~= nil then
		sql_str = string.format( "%s priority=%d,", sql_str, json["Priority"])
	end

	if json["Actions"] ~= nil then
		local para_str = cjson.encode(json["Actions"])
		sql_str = string.format( "%s actions=\'%s\',", sql_str, para_str)
	end

	if json["StartTime"] ~= nil then
		sql_str = string.format( "%s start_time=\'%s\',", sql_str, json["StartTime"])
	end

	if json["EndTime"] ~= nil then
		sql_str = string.format( "%s end_time=\'%s\',", sql_str, json["EndTime"])
	end

	if json["StartDate"] ~= nil then
		sql_str = string.format( "%s start_date=\'%s\',", sql_str, json["StartDate"])
	end

	if json["EndDate"] ~= nil then
		sql_str = string.format( "%s end_date=\'%s\',", sql_str, json["EndDate"])
	end

	if json["Running"] ~= nil then
		sql_str = string.format( "%s running=%d,", sql_str, json["Running"])
	end

	sql_str = string.format( "%s where rule_uuid=\'%s\'", sql_str, rule_uuid)
	sql_str = string.gsub(sql_str, ', where', ' where', 1)
	ngx.log(ngx.INFO," ", sql_str)
	local res,err = db:execute(sql_str)
	--以上字段都不存在时err会反错
	return res,err
end

--HTTP GET  查询一条策略
function g_orm_info_M.query_rule_tbl_by_uuid(rule_uuid)
	local sql_str = string.format("select * from run_rule_tbl where rule_uuid=\'%s\'",rule_uuid)
	local res,err = db:query(sql_str)
	return res,err
end

--HTTP GET  查询一个设备的所有策略
function g_orm_info_M.query_rule_tbl_by_devid(dev_type, dev_id)
	local sql_str = string.format("select * from run_rule_tbl where dev_type=\'%s\' and dev_id=%d",dev_type, dev_id)
	--ngx.log(ngx.ERR," ",sql_str)
	local res,err = db:query(sql_str)
	return res,err
end

--HTTP GET  查询数据库中所有策略
function g_orm_info_M.query_rule_tbl_all()
	local sql_str = string.format("select * from run_rule_tbl")
	local res,err = db:query(sql_str)
	return res,err
end

--策略执行  获取数据库中所有设备类型
function g_orm_info_M.query_rule_tbl_for_devtype()
	local sql_str = string.format("select distinct trim(dev_type) from run_rule_tbl")
	local res,err = db:query(sql_str)
	return res,err
end

--策略执行  根据dev_type获取该类型设备的所有dev_id
function g_orm_info_M.query_rule_tbl_for_devid(dev_type)
	local sql_str = string.format("select distinct dev_id from run_rule_tbl where trim(dev_type)=\'%s\' order by dev_id ASC", dev_type)
	--ngx.log(ngx.ERR," ",sql_str)
	local res,err = db:query(sql_str)
	return res,err
end

--策略执行  根据dev_type和dev_id获取该设备的所有channel
function g_orm_info_M.query_rule_tbl_for_channel(dev_type, dev_id)
	local sql_str = string.format("select distinct dev_channel from run_rule_tbl where trim(dev_type)=\'%s\' and dev_id=%d order by dev_channel ASC", dev_type, dev_id)
	--ngx.log(ngx.ERR," ",sql_str)
	local res,err = db:query(sql_str)
	return res,err
end

--策略执行  获取最优策略
function g_orm_info_M.query_rule_tbl_by_channel(dev_type, dev_id, channel)
	local sql_str = string.format("select * from (select * from run_rule_tbl where (trim(dev_type)=\'%s\' and dev_id=%d and dev_channel=%d and start_date<=current_date and current_date<=end_date))  as result_date where ((start_time<=current_time and current_time<end_time) or (start_time>=end_time and ((start_time<=current_time and current_time<'24:00:00' and current_date!=end_date) or ('00:00:00'<=current_time and current_time<end_time and current_date!=start_date)))) order by priority ASC,start_time DESC,id ASC limit 1", dev_type, dev_id, channel)
	--ngx.log(ngx.ERR," ",sql_str)
	local res,err = db:query(sql_str)
	return res,err
end

--策略执行  更新channel的running
function g_orm_info_M.update_rule_tbl_running(dev_type, dev_id, channel, running)
	local sql_str = string.format("update run_rule_tbl set running=%d where dev_type=\'%s\' and dev_id=%d and dev_channel=%d", running, dev_type, dev_id, channel)
	ngx.log(ngx.INFO," ", sql_str)
	local res,err = db:execute(sql_str)
	return res,err
end

--通用查询方法
function g_orm_info_M.query_table(sql_str)
	--ngx.log(ngx.ERR," ",sql_str)
	local res,err = db:query(sql_str)
	return res,err
end

function g_orm_info_M.exec_sql(sql_str)
	ngx.log(ngx.INFO," ", sql_str)
	local res,err = db:execute(sql_str)
	return res,err
end

return g_orm_info_M