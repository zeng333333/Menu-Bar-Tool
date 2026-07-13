-- AtlasGroupProcess coreless
 -- AtlasGroupProcess coreless /System/Volumes/Data/vault/Atlas2-s/RPC.lua

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

-- local RunShellCommand = Atlas.loadPlugin("/Users/gdlocal/Library/Atlas2/Plugins/RunShellCommand")
-- local user = RunShellCommand.run("Users").output
-- user = string.gsub(user, "\r", "")
-- user = string.gsub(user, "\n", "")

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

-- local logFile = log_init("/Users/"..user.."/Desktop/RPC_" .. getdatetime_h() .. ".log")
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
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------RPC----------------------------------------------------------------------

function RPC_init(ip,port,time)
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

function RPC_send(rpcClient,paraTab)
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

function RPC_close(rpcClient)
    local status, ret = xpcall(rpcClient.teardown, debug.traceback)
end

function slot_reset(rpcClient)
    paraTab = {}
    paraTab["commands"] = 'power.set_volt(VBATT,0,4000)'
    RPC_send(rpcClient,paraTab)

    paraTab["commands"] = 'relay.reset()'
    RPC_send(rpcClient,paraTab)

    paraTab["commands"] = 'power.reset()'
    RPC_send(rpcClient,paraTab)
end

------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------function-----------------------------------------------------------------

function write_FixSN()
    paraTab = {} 
    -- paraTab["commands"] = 'tib_eeprom.write_string(0x510,"CYG-S013-S01")'
    -- paraTab["commands"] = "tib_eeprom.read_string(0x510,14)"
    paraTab["commands"] = "wib.fixture_id()"
    -- paraTab["commands"] = 'wib.write_data("fixture_id","SC250617ICT-03")'
    -- paraTab["commands"] = 'eeprom.read_string("0x00",25,"eeprom_sib")'
    -- paraTab["commands"] = 'eeprom.write_string("0x00","SC250617ICT-06","eeprom_spb")'

    -- SC250924ICT-08
    local port = 7801
    -- local ip_tab = {32,33,34,35,36,37,38,39}
    local ip_tab = {36,37,38,39}
    -- local ip_tab = {32}

    for _, ip in ipairs(ip_tab) do
        ip = "192.168.99."..ip
        loglog("=============IP:"..ip.."==============")
        rpcClient = RPC_init(ip,port)
        if rpcClient then
            ret = RPC_send(rpcClient,paraTab)
            RPC_close(rpcClient)
        else
            loglog("=============RPC_init fail:"..ip.."==============")
        end
    end
end


function DOE()
    ip = "192.168.99.33"
    loglog("=============IP:"..ip.."==============")
    rpcClient = RPC_init(ip,"7801")
    slot_reset(rpcClient)
    paraTab = {}
    if rpcClient then
        paraTab["commands"] = 'relay.switch("GND_DIVIDE","CONNECT")'
        RPC_send(rpcClient,paraTab)

        paraTab["commands"] = 'io_ctrl.set([[3051,1]])'
        RPC_send(rpcClient,paraTab)

        paraTab["commands"] = 'relay.switch("VBATT","VBAT_PP3V0_4V3_BATT_JMP_2A")'
        RPC_send(rpcClient,paraTab)

        paraTab["commands"] = 'power.set_volt(VBATT,3800,4000)'
        RPC_send(rpcClient,paraTab)

        for i=1,1 do
            paraTab["commands"] = 'power.measure(IBATT_JMP_10MA)'
            RunShellCommand.run("sleep " .. tostring(0.1))
            RPC_send(rpcClient,paraTab)
            -- measure_ma(rpcClient,paraTab)
        end

        -- paraTab["commands"] = 'relay.switch("IBATT_CURR_SWITCH","VBAT_PP3V0_4V3_2A")'
        -- RPC_send(rpcClient,paraTab)
        -- paraTab["commands"] = 'relay.switch("CURR_SNS_SEL_VBATT_CURR_2A","CONNECT")'
        -- RPC_send(rpcClient,paraTab)

        -- RunShellCommand.run("sleep " .. tostring(1000 / 1000))

        slot_reset(rpcClient)

        RPC_close(rpcClient)
    else
        loglog("=============RPC_init fail:"..ip.."==============")
    end
end


function write_cal()
    -- read_calibration
    -- remove_parameter
    -- add_parameter
    -- update_calibration
    local port = 7801
    local ip_tab = {32,33,34,35,36,37,38,39}
    -- local ip_tab = {36,37,38,39}
    -- local ip_tab = {32}
    paraTab = {}
    for _, ip in ipairs(ip_tab) do
        ip = "192.168.99."..ip
        loglog("=============IP:"..ip.."==============")
        rpcClient = RPC_init(ip,port)
        if rpcClient then
            paraTab["commands"] = 'syscal.read_calibration("CTX","CTX_CH_14")'
            ret = RPC_send(rpcClient,paraTab)
            print(ret,type(ret))
            print(ret[1]["gain"])
            print(ret[1]["offset"])
            print(ret[1]["threshold"])

            offset = ret[1]["offset"] - 0.2

            paraTab["commands"] = 'syscal.add_parameter("CTX","CTX_CH_14",'..ret[1]["gain"]..','..offset..','..ret[1]["threshold"]..')'
            ret = RPC_send(rpcClient,paraTab)

            paraTab["commands"] = 'syscal.update_calibration("CTX","CTX_CH_14")'
            ret = RPC_send(rpcClient,paraTab)

            RPC_close(rpcClient)
        else
            loglog("=============RPC_init fail:"..ip.."==============")
        end
    end
end

function write_cal2()
    -- read_calibration
    -- remove_parameter
    -- add_parameter
    -- update_calibration
    local port = 7801
    local ip_tab = {32,33,34,35,36,37,38,39}
    -- local ip_tab = {36,37,38,39}
    -- local ip_tab = {32}
    paraTab = {}
    for _, ip in ipairs(ip_tab) do
        ip = "192.168.99."..ip
        loglog("=============IP:"..ip.."==============")
        rpcClient = RPC_init(ip,port)
        if rpcClient then

            paraTab["commands"] = 'syscal.add_parameter("PSU","POWER_VOLT_SET",'.."1"..','.."0"..','.."0.001"..')'
            ret = RPC_send(rpcClient,paraTab)
            paraTab["commands"] = 'syscal.update_calibration("PSU","POWER_VOLT_SET")'
            ret = RPC_send(rpcClient,paraTab)

            paraTab["commands"] = 'syscal.add_parameter("PSU","POWER_CURR_SET",'.."1"..','.."0"..','.."0.001"..')'
            ret = RPC_send(rpcClient,paraTab)
            paraTab["commands"] = 'syscal.update_calibration("PSU","POWER_CURR_SET")'
            ret = RPC_send(rpcClient,paraTab)

            -- LOW_CURR_OUT_NA Force_UVP_3450
            paraTab["commands"] = 'syscal.add_parameter("ADC","VAR_CURR",'.."1"..','.."0"..','.."0.001"..')'
            ret = RPC_send(rpcClient,paraTab)
            paraTab["commands"] = 'syscal.update_calibration("ADC","VAR_CURR")'
            ret = RPC_send(rpcClient,paraTab)

            RPC_close(rpcClient)
        else
            loglog("=============RPC_init fail:"..ip.."==============")
        end
    end
end

function write_doe()
    -- read_calibration
    -- remove_parameter
    -- add_parameter
    -- update_calibration
    local port = 7801
    local ip_tab = {39}
    -- local ip_tab = {36,37,38,39}
    -- local ip_tab = {32}
    paraTab = {}
    for _, ip in ipairs(ip_tab) do
        ip = "192.168.99."..ip
        loglog("=============IP:"..ip.."==============")
        rpcClient = RPC_init(ip,port)
        if rpcClient then
            paraTab["commands"] = 'syscal.read_calibration("PSU")'
            ret = RPC_send(rpcClient,paraTab)
            RPC_close(rpcClient)
        else
            loglog("=============RPC_init fail:"..ip.."==============")
        end
    end
end
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------MAIN---------------------------------------------------------------------
FixtureControlCore = {}
FixtureControlCore.rpcClientObjc = nil
FixtureControlCore.mutexPlugin = nil
FixtureControlCore.serverName = 'electric_control_16up'
FixtureControlCore.host = '192.168.99.39'
FixtureControlCore.port = 7805
FixtureControlCore.slotCount = 8

-- local mutex             = require("mutex")


function FixtureControlCore.init(rpcClientObjc, mutexPlugin)
    -- helper.LogInfo("======FixtureControl.init======")
    if rpcClientObjc then
        FixtureControlCore.rpcClientObjc = rpcClientObjc
        FixtureControlCore.rpcClientObjc.init(FixtureControlCore.host, FixtureControlCore.port)
        FixtureControlCore.rpcClientObjc.commands(string.format("connect(%s,tcp://%s:%d)", FixtureControlCore.serverName, FixtureControlCore.host, FixtureControlCore.port), 6000)
    end
    if mutexPlugin then
        FixtureControlCore.mutexPlugin = mutexPlugin
    end
end


function FixtureControlCore.setLed(slotId, color)
    -- slotId: UUT1/2/3/4/5/6/7/8 STATUS
    -- color: BLUE GREEN RED YELLOW IDLE
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    local _identifier = "identifier"
    local __fixtureControl = function(command, timeout)
        local status, ret = xpcall(FixtureControlCore.rpcClientObjc.commands, debug.traceback, command, timeout)
        -- helper.LogInfo("FixtureControl set LED: ", slotId, color, status, ret)
        return status
    end
    local command = string.format('electric_control_16up.lucifer.set_led_status(%s,%s)', slotId, color)
    local timeout = 1000
    -- helper.LogInfo('=====================>> command ', command)
    result = mutex.runWithLock(FixtureControlCore.mutexPlugin or Atlas.loadPlugin("MutexPlugin"), _identifier, __fixtureControl, command, timeout)
    return result
end

-- mutexPlugin = Atlas.loadPlugin("MutexPlugin")
-- fixtureControlPlugin = Atlas.loadPlugin("MIXRPCRelay")
-- FixtureControlCore.init(fixtureControlPlugin, mutexPlugin)
-- FixtureControlCore.setLed('STATUS', 'IDLE')

-- local slot_tab = {5,6,7,8}

-- for _, slot in ipairs(slot_tab) do
--     -- FixtureControlCore.setLed(string.format('UUT%s', slot), 'YELLOW')
--     FixtureControlCore.setLed(string.format('UUT%s', slot), 'GREEN')
--     -- FixtureControlCore.setLed(string.format('UUT%s', slot), 'RED')
-- end

TEST = [[IMU_GYRO:
Custom Id 6 : 1
]]

TEST = [[Power Mode [enum]  : 4]]
TEST = [[Gyro INT2 Drive Frequency: 35552 Hz]]
delimiter = "IMU_GYRO%:.-Custom%s*Id%s*%d+%s*%:%s*%d+"
delimiter = "IMU_GYRO"
delimiter = "Power%s*Mode%s*%[enum%]%s*%:%s*%d+"
delimiter = "Power Mode"
delimiter = "Gyro INT2 Drive Frequency:"
print(string.find(TEST, delimiter, 1, true))
print("--------------------------------")

input = [[
chromite i2c_cmd 0xA0 0x01 0x00 0x00 0x00 0x01 0xFF 0x00
c
hromite i2c_cmd 0xA0 0x01 0x00 0x00 0x00 0x01 0xFF 0x00

Cmd = 0xa0, CmdLen = 0x7, R
spLen = 0x5
 Status: 0x00 
00000000: 00 00 eb 0f 00  
]]
local pattern = 'Status%:%s*0x(%x%x)%s*[\r\n]%s*%x%x%x%x%x%x%x%x%:%s*(%x%x)%s*(%x%x)%s*(%x%x)%s*(%x%x)%s*(%x%x)'

print(string.match(input, pattern))
-- local byte0, byte1, byte2, byte3, byte4, byte5 = string.match(input, pattern)
print("--------------------------------")

input = [[
chromite i2c_cmd 0x05
chromite
 i2c_cmd 0x05
Cmd = 0x5, CmdLen = 0x0, RspLen = 0x6
 Status: 0x00 
00000000: 00 00 00 1b 01 00        
]]
local pattern = 'Status%:%s*0x(%x%x).-%x%x%x%x%x%x%x%x%:.-(%x%x).-(%x%x).-(%x%x).-(%x%x).-(%x%x).-(%x%x)'
local pattern2 = 'Status%:%s*0x(%x%x).-%x%x%x%x%x%x%x%x%:.-(%x%x).-(%x%x).-(%x%x).-(%x%x).-(%x%x).-(%x%x)'

print(string.match(input, pattern))
print("--------------------------------")
print(string.match(input, pattern2))
-- local byte0, byte1, byte2, byte3, byte4, byte5 = string.match(input, pattern)
print("--------------------------------")


input = [[
Address = 0x40003c7c, RspLen = 1
0x01
]]
local pattern = 'RspLen%s*%=.-1.-0x(%w+)'

print(string.match(input, pattern))
print("--------------------------------")

  

input = [[
2c_read 0x40003C7C 0x01
Address = 0x40003c7c, RspLen = 1
00000000: 01        
]]
local pattern = 'RspLen%s*%=.-1.-00000000%:%s*(%w+)'

print(string.match(input, pattern))
print("--------------------------------")


input = [[
00000000: 01 00 00 00 1f 03 01 00  1f 04 c3 04 76 ef d2 fa |........ ....v...|
00000010: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 |........ ........|
00000020: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 |........ ........|
00000030: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 |........ ........|
00000040: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 |........ ........|
00000050: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 |........ ........|
00000060: 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 |........ ........|
00000070: 00 00 00 00 00 00 00 00  00 00 00 00 71 24 00 00 |........ ....q$..|  
]]

for byte in string.gmatch(input, '(%x%x)%s') do
    print(tonumber("0x"..byte))
    -- print(byte)

end
print("--------------------------------")


-- response = [[
-- >chromite i2c_read 0x40001424 4
-- Address = 0x40001424, RspLen = 4
-- 00000000: 82 0f 00 00     
-- ]]

-- print(string.match(response,"RspLen%s*%=%s*4.-00000000%:%s*(%w%w).-(%w%w).-%w%w.-%w%w"))
-- print("--------------------------------")
tab = {1,23,123,21,-2}

print("--------------------------------")
print(math.min(tab))
print("--------------------------------")

-- DOE()
-- write_cal2()
-- write_doe()
-- write_FixSN()


log_close()
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------