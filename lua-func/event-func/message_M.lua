--message module
local message_M = {version='v1.0.1'}


function message_M.creat_online_object(gw_uuid,device_list)
    local online_object = {}
    online_object["Token"] = "7GBox"
    online_object["Event"] = "StatusUpload"
    online_object["GW"] = gw_uuid
    online_object["Devices"] = device_list
    return online_object
end

function message_M.creat_offline_object(gw_uuid, device_list)
    local offline_object = {}
    offline_object["Token"] = "7GBox"
    offline_object["Event"] = "StatusUpload"
    offline_object["GW"] = gw_uuid
    offline_object["Devices"] = device_list
    return offline_object
end

return message_M