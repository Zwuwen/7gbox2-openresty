--udp module
udpcli_M = {version='v1.0.1'}


local udpsock = nil

function udpcli_M.init(ip, port, timeout)
    udpsock = ngx.socket.udp()
    udpsock:settimeout(timeout)
    local ok,err = udpsock:setpeername(ip,port)
end

function udpcli_M.uninit()
    udpsock:close()
end

function udpcli_M.send(str)
    local ok,err = udpsock:send(str)
    return ok,err
end	

return udpcli_M

