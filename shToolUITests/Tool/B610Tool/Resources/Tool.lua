-- AtlasGroupProcess coreless
 -- AtlasGroupProcess coreless /System/Volumes/Data/vault/Atlas2-s/RPC.lua

------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------loglog-------------------------------------------------------------------
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

function fileRead(path)
  if not path then return nil end
  local file = io.open(path, "r")
  if file then
    data = file:read("*all")
    file:close()
    return data
  end
  return ""
end

function get_users_name()
    os.execute("rm /tmp/zjx/1.txt")
    os.execute("mkdir -p /tmp/zjx | touch /tmp/zjx/1.txt | echo $(Users)  >> /tmp/zjx/1.txt")
    users_name= fileRead("/tmp/zjx/1.txt")
    return users_name
end

local user = get_users_name()
user = string.gsub(user, "\r", "")
user = string.gsub(user, "\n", "")

function log_init(logPath)
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

local logFile = log_init("/Users/"..user.."/Desktop/RPC_" .. getdatetime_h() .. ".log")
function loglog(...)
    if logFile then
        local timestamp = getdatetime()
        logFile:write(timestamp..":")
        -- local status,file = xpcall(logFile:write,debug.traceback, ... )
        if type(...) ~= "table" then
            logFile:write(tostring(...))
        end
        logFile:write("\n")
    else
        print(...)
    end
end
function log_close()
    if logFile then
        logFile:close()
    end
end

function splitString(inputStr, delimiter)
    if not inputStr or not delimiter then return nil end

    inputStr = tostring(inputStr)
    delimiter = tostring(delimiter)

    if delimiter == '' then return false end

    local result = {}
    local currentPos = 1
    while true do
        local startPos, endPos = string.find(inputStr, delimiter, currentPos, true)
        if not startPos then
            break
        end
        table.insert(result, string.sub(inputStr, currentPos, startPos - 1))
        currentPos = endPos + 1
    end
    table.insert(result, string.sub(inputStr, currentPos))
    return result
end
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------RPC----------------------------------------------------------------------

function RPC_init(ip,port,time)
    local timeout = time or 3
    local fixturePlugin = Atlas.loadPlugin("MIXRPCRelay")
    -- fixturePlugin.init(ip, tonumber(port))
    local status, ret = xpcall(fixturePlugin.commands, debug.traceback, string.format("connect(dut0,tcp://%s:%s)", ip, port), timeout)
    if status == true then 
        return fixturePlugin
    else
        return nil
    end
end

function RPC_init_dut1(ip,port,time)
    local timeout = time or 3
    local fixturePlugin = Atlas.loadPlugin("MIXRPCRelay")
    -- fixturePlugin.init(ip, tonumber(port))
    local status, ret = xpcall(fixturePlugin.commands, debug.traceback, string.format("connect(dut1,tcp://%s:%s)", ip, port), timeout)
    if status == true then 
        return fixturePlugin
    else
        return nil
    end
end

function RPC_init_50000(ip,port,time)
    local timeout = time or 3
    local fixturePlugin = Atlas.loadPlugin("MIXRPCRelay")
    -- fixturePlugin.init(ip, tonumber(port))
    local status, ret = xpcall(fixturePlugin.commands, debug.traceback, string.format("connect(manager,tcp://%s:%s)", ip, port), timeout)
    if status == true then 
        return fixturePlugin
    else
        return nil
    end
end

function RPC_send(rpcClient,paraTab)
    local command = paraTab.commands
    local timeout = paraTab.timeout or 6000
    local dutserver = paraTab.dutserver or "dut0."
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

function RPC_close(rpcClient)
    local status, ret = xpcall(rpcClient.teardown, debug.traceback)
end

------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------function-----------------------------------------------------------------

function VENDOR_ID(ip)
    paraTab = {} 
    local port = 7801
    loglog("=============IP:"..ip.."==============")
    ip_4=splitString(ip,".")[4]
    rpcClient = RPC_init(ip,port)
    if rpcClient then
        paraTab["commands"] = 'eeprom.write_string("0x00","Suncode","eeprom_sib")'
        ret = RPC_send(rpcClient,paraTab)
        paraTab["commands"] = 'eeprom.read_string("0x00",10,"eeprom_sib")'
        ret = RPC_send(rpcClient,paraTab)
        RPC_close(rpcClient)
    else
        loglog("=============RPC_init fail:"..ip.."==============")
    end
    rpcClient = RPC_init_dut1(ip,7802)
    if rpcClient then
        paraTab.dutserver = "dut1."
        paraTab["commands"] = 'eeprom.write_string("0x00","Suncode","eeprom_sib")'
        ret = RPC_send(rpcClient,paraTab)
        paraTab["commands"] = 'eeprom.read_string("0x00",10,"eeprom_sib")'
        ret = RPC_send(rpcClient,paraTab)
        RPC_close(rpcClient)
    else
        loglog("=============RPC_init fail:"..ip.."==============")
    end
end

function FixSnWrite(ip,FixSn)
    paraTab = {} 
    local port = 7801
    loglog("=============IP:"..ip.."==============")
    ip_4=splitString(ip,".")[4]
    rpcClient = RPC_init(ip,port)
    if rpcClient then
        paraTab["commands"] = 'eeprom.write_string("0x10","'..FixSn..'","eeprom_sib")'
        ret = RPC_send(rpcClient,paraTab)
        paraTab["commands"] = 'eeprom.read_string("0x10",10,"eeprom_sib")'
        ret = RPC_send(rpcClient,paraTab)
        RPC_close(rpcClient)
    else
        loglog("=============RPC_init fail:"..ip.."==============")
    end
    rpcClient = RPC_init_dut1(ip,7802)
    if rpcClient then
        paraTab.dutserver = "dut1."
        paraTab["commands"] = 'eeprom.write_string("0x10","'..FixSn..'","eeprom_sib")'
        ret = RPC_send(rpcClient,paraTab)
        paraTab["commands"] = 'eeprom.read_string("0x10",10,"eeprom_sib")'
        ret = RPC_send(rpcClient,paraTab)
        RPC_close(rpcClient)
    else
        loglog("=============RPC_init fail:"..ip.."==============")
    end
end



function bless(ip)
    paraTab = {} 
    local port = 50000
    loglog("=============IP:"..ip.."==============")
    rpcClient = RPC_init_50000(ip,port)
    if rpcClient then
        paraTab["commands"] = 'configcheck.bless()'
        paraTab["dutserver"] = 'manager.'
        ret = RPC_send(rpcClient,paraTab)
        RPC_close(rpcClient)
    else
        loglog("=============RPC_init fail:"..ip.."==============")
    end
end

------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------MAIN---------------------------------------------------------------------
args = Group.args[1]["args"]
ip = args[1]
func = args[2]
arg1 = args[3]
arg2 = args[4]
print(ip,func,arg1,arg2)

if func=="VENDOR_ID_lua" then
    VENDOR_ID(ip)
end
if func=="FixSnWrite_lua" then
    FixSnWrite(ip,arg1)
end
log_close()
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------