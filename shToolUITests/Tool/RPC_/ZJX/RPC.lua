local RPC = {}
local commonFunc            = require("CommonFunc")
RPC.user = CommonFunc.get_users_name()
RPC.user = string.gsub(user, "\r", "")
RPC.user = string.gsub(user, "\n", "")
RPC.logFile = nil
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------loglog-------------------------------------------------------------------
-- function tab_json(t,N)
--     local tabFlag = false
--     local retTab = {}
--     if not N then
--         N = ""
--     end
--     local tab_N = N.."    "
--     for k,v in pairs(t) do
--         local key = k
--         if type(v) == "table" then
--             t[k] = tab_json(v,tab_N)
--         elseif type(v) == "boolean" then
--             if v == true then
--                 t[k] = "true"
--             else
--                 t[k] = "false"
--             end
--         elseif type(v) == "string" then
--             t[k] = t[k]
--         end
--         local vaule = t[k]
--         table.insert(retTab,key..":"..vaule..",")
--     end
--     return "{".."\n"..tab_N..table.concat(retTab, "\n"..tab_N).."\n"..tab_N.."}"
-- end

local function is_array(tab)
    local count = 0
    for k, _ in pairs(tab) do
        if type(k) ~= "number" then
            return false
        end
        count = count + 1
    end
    return count == #tab
end

local function json_encode_pro(value,N)
    N = N or ""
    local tab_N = N.."    "
    local vtype = type(value)
    if vtype == "nil" then
        return "null"
    end
    if vtype == "number" then
        return tostring(value)
    end
    if vtype == "boolean" then
        return value and "true" or "false"
    end
    if vtype == "string" then
        -- return "\"" .. json_escape(value) .. "\""
        return value
    end
    if vtype == "table" then
        if is_array(value) then
            local parts = {}
            for i = 1, #value do
                parts[#parts + 1] = json_encode_pro(value[i],tab_N)
            end
            -- return "[" .. table.concat(parts, ",") .. "]"
            return "[".."\n"..tab_N..table.concat(parts, ",\n"..tab_N).."\n"..tab_N.."]"
        end
        local parts = {}
        for k, v in pairs(value) do
            parts[#parts + 1] = json_encode_pro(tostring(k),tab_N) .. ":" .. json_encode_pro(v,tab_N)
        end
        -- return "{" .. table.concat(parts, ",") .. "}"
        return "{".."\n"..tab_N..table.concat(parts, ",\n"..tab_N).."\n"..tab_N.."}"
    end
    return json_encode_pro(tostring(value),tab_N)
end

function RPC.log_init(logPath)
    print(logPath)
    local status,file = xpcall(io.open, debug.traceback, logPath, "a+")
    -- local status,file = xpcall(io.open, debug.traceback, logPath, "w+")
    -- local file = io.open (logPath, "w+")
    if status then
        return file
    else
        return nil
    end
end

function getdatetime()
    return tostring(os.date("%m-%d-%H-%M-%S",os.time()))
end

function getdatetime_h()
    return tostring(os.date("%m-%d-%H",os.time()))
end

function loglog(...)
    if not RPC.logFile then
        RPC.logFile = RPC.log_init("/Users/"..user.."/Desktop/RPC_" .. getdatetime_h() .. ".log")
    end
    local timestamp = getdatetime()
    RPC.logFile:write(timestamp..":")
    -- local status,file = xpcall(logFile:write,debug.traceback, ... )
    if type(...) ~= "table" then
        RPC.logFile:write(tostring(...))
    end
    RPC.logFile:write("\n")

end

function log_close()
    if RPC.logFile then
        RPC.logFile:close()
    end
end

------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------RPC----------------------------------------------------------------------

function RPC.RPC_init(ip,port,time)
    local timeout = time or 3
    local fixturePlugin = Atlas.loadPlugin("MIXRPCRelay")
    fixturePlugin.init(ip, tonumber(port))
    local status, ret = xpcall(fixturePlugin.commands, debug.traceback, string.format("connect(dut0,tcp://%s:%s)", ip, port), timeout)
    if status == true then 
        return fixturePlugin
    else
        return nil
    end
end

function RPC.RPC_send(rpcClient,paraTab)
    local command = paraTab.commands
    local timeout = paraTab.timeout or 6000
    local dutserver = "dut0."
    local cmd = dutserver..command
    local status, response = xpcall(rpcClient.commands, debug.traceback, cmd, timeout or 3)
    if status then
        loglog("===========================")
        loglog("cmd:")
        loglog(cmd)
        if type(cmd) == "table" then
            for i,v in ipairs(cmd) do
                loglog(i,v)
            end
        end
        loglog("response:")
        if type(response) == "table" then
            response_str = json_encode_pro(response)
            -- for i,v in ipairs(response) do
            --     loglog(i,v)
            --     if type(v) == "table" then
            --         for k2, v2 in pairs(v) do
            --             loglog(k2)
            --             loglog(v[tostring(k2)])
            --         end
            --     end
            -- end
            xpcall(loglog, debug.traceback, response_str)
        else
            xpcall(loglog, debug.traceback, response)
        end
        loglog("===========================")
        return response
    else     
        return "FAIL"
    end
end

function RPC.RPC_close(rpcClient)
    local status, ret = xpcall(rpcClient.teardown, debug.traceback)
end

return RPC