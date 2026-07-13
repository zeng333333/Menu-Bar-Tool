------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------MAIN---------------------------------------------------------------------
FixtureControlCore = {}
FixtureControlCore.rpcClientObjc = nil
FixtureControlCore.mutexPlugin = nil
FixtureControlCore.serverName = 'electric_control_16up'
FixtureControlCore.host = '111.111.111.32'
FixtureControlCore.port = 7809
FixtureControlCore.slotCount = 8

-- local mutex             = require("mutex")
-- /usr/local/Atlas/Plugins/MutexPlugin.l-dylib
local helper             = require("helper")


function FixtureControlCore.init(rpcClientObjc, mutexPlugin)
    -- helper.LogInfo("======FixtureControl.init======")
    if rpcClientObjc then
        FixtureControlCore.rpcClientObjc = rpcClientObjc
        -- FixtureControlCore.rpcClientObjc.init(FixtureControlCore.host, FixtureControlCore.port)
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

function FixtureControlCore.readTraySensor(pos)
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    local timeout = 1000
    local command = nil
    if pos == 'in' then
        command = 'electric_control_16up.lucifer.read_in_sensor()'
    elseif pos == 'out' then
        command = 'electric_control_16up.lucifer.read_out_sensor()'
    elseif pos == 'up' then
        command = 'electric_control_16up.lucifer.read_up_sensor()'
    elseif pos == 'down' then
        command = 'electric_control_16up.lucifer.read_down_sensor()'
    end
    if command then
        local status, ret = xpcall(FixtureControlCore.rpcClientObjc.commands, debug.traceback, command, timeout)
        helper.LogInfo("FixtureControl read tray sensor: ", pos, status, ret)
        return ret
    end
end

function FixtureControlCore.setTrayPosition(pos)
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    local timeout = 6000
    local command = nil
    if pos == 'in' then
        command = 'electric_control_16up.lucifer.fixture_in()'
    elseif pos == 'out' then
        command = 'electric_control_16up.lucifer.fixture_out()'
    elseif pos == 'up' then
        command = 'electric_control_16up.lucifer.fixture_up()'
    elseif pos == 'down' then
        command = 'electric_control_16up.lucifer.fixture_down()'
    end
    if command then
        local status, ret = xpcall(FixtureControlCore.rpcClientObjc.commands, debug.traceback, command, timeout)
        helper.LogInfo("FixtureControl set tray position: ", pos, status, ret)
        return ret
    end
end


function FixtureControlCore.readThroughSensor()
    local command = 'electric_control_16up.lucifer.read_through_sensor()'
    local timeout = 1
    local status, ret = xpcall(FixtureControlCore.rpcClientObjc.commands, debug.traceback, command, timeout)
    if status and ret == 1 then
        return true
    end
    return false
end

function FixtureControlCore.setMagnet(state)
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    local command = string.format('electric_control_16up.lucifer.set_magnet_status(%s)', state)
    local timeout = 1000
    local status, ret = xpcall(FixtureControlCore.rpcClientObjc.commands, debug.traceback, command, timeout)
    helper.LogInfo("FixtureControl set magnet: ", state, status, ret)
    return status
end

function FixtureControlCore.press()
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    local timeout = 20
    local status = true
    local startTime = os.time()
    local stateIn = 0
    FixtureControlCore.setTrayPosition('in')
    repeat
        stateIn = FixtureControlCore.readTraySensor('in')
        if stateIn and stateIn == 1 then
            break
        end
        os.execute('sleep 0.5')
    until (os.difftime(os.time(), startTime) >= timeout)
    FixtureControlCore.setMagnet('on')
    os.execute('sleep 0.5')
    -- Double comfirm sensor state
    stateIn = FixtureControlCore.readTraySensor('in')
    if FixtureControlCore.readThroughSensor() == false then
        return false
    end
    local stateDown = FixtureControlCore.readTraySensor('down')
    if stateDown and stateDown == 1 then
        return true
    end
    if stateIn and stateIn == 1 then
        local ret = FixtureControlCore.setTrayPosition('down')
        timeout = 5
        startTime = os.time()
        repeat
            stateDown = FixtureControlCore.readTraySensor('down')
            if stateDown and stateDown == 1 then
                return true
            end
            os.execute('sleep 0.5')
        until (os.difftime(os.time(), startTime) >= timeout)
    end
    return false
end

function FixtureControlCore.release()
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    local ret
    local timeout = 20
    local status = true
    local startTime = os.time()
    local stateIn = 0
    FixtureControlCore.setTrayPosition('up')
    repeat
        stateUp = FixtureControlCore.readTraySensor('up')
        if stateUp and stateUp == 1 then
            break
        end
        os.execute('sleep 0.5')
    until (os.difftime(os.time(), startTime) >= timeout)
    stateIn = FixtureControlCore.readTraySensor('in')
    if stateIn and stateIn == 1 then 
        FixtureControlCore.setMagnet('off')
        local ret = FixtureControlCore.setTrayPosition('out')
        timeout = 5
        startTime = os.time()
        repeat
            stateIn = FixtureControlCore.readTraySensor('in')
            if stateIn and stateIn == 0 then
                return true
            end
            os.execute('sleep 0.5')
        until (os.difftime(os.time(), startTime) >= timeout)
    end
    return false
end

function FixtureControlCore.T_in()
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    local timeout = 20
    local status = true
    local startTime = os.time()
    local stateIn = 0
    FixtureControlCore.setTrayPosition('in')
    print("setTrayPositionsetTrayPositionsetTrayPosition")
    repeat
        stateIn = FixtureControlCore.readTraySensor('in')
        if stateIn and stateIn == 1 then
            break
        end
        os.execute('sleep 0.5')
    until (os.difftime(os.time(), startTime) >= timeout)
    FixtureControlCore.setMagnet('on')
    os.execute('sleep 0.5')
    -- Double comfirm sensor state
    stateIn = FixtureControlCore.readTraySensor('in')
    if FixtureControlCore.readThroughSensor() == false then
        return false
    end
    return true
end

-- function FixtureControlCore.T_out()
--     if FixtureControlCore.rpcClientObjc == nil then return nil end
--     local timeout = 20
--     local status = true
--     local startTime = os.time()
--     local stateOut = 0
--     FixtureControlCore.setTrayPosition('out')
--     repeat
--         stateOut = FixtureControlCore.readTraySensor('out')
--         if stateOut and stateOut == 1 then
--             break
--         end
--         os.execute('sleep 0.5')
--     until (os.difftime(os.time(), startTime) >= timeout)
--     FixtureControlCore.setMagnet('off')
--     os.execute('sleep 0.5')
--     -- Double comfirm sensor state
--     stateOut = FixtureControlCore.readTraySensor('out')
--     if FixtureControlCore.readThroughSensor() == false then
--         return false
--     end
--     return true
-- end

function FixtureControlCore.T_out()
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    FixtureControlCore.setMagnet('off')
    os.execute('sleep 0.1')
    FixtureControlCore.setTrayPosition('out')
    return true
end

function FixtureControlCore.T_down()
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    FixtureControlCore.setTrayPosition('down')
    return true
end

function FixtureControlCore.T_up()
    if FixtureControlCore.rpcClientObjc == nil then return nil end
    FixtureControlCore.setTrayPosition('up')
    return true
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

function writeToFile(path, data, mode)
    local fileMode = mode or "w"
    local file, err = io.open(path, fileMode)
    if file then
        local success, writeErr = file:write(data)
        file:close()
        return success, writeErr
    end
    return nil, err
end

function show_message(title,message)
    local title = title or "错误"
    local message = message or "ERROR"
    local info = string.format('osascript -e \'display alert "%s" message "%s" as critical\'',title,message)
    os.execute("mkdir -p /tmp/zjx;touch /tmp/zjx/show_message.sh")
    os.execute("rm /tmp/zjx/show_message.sh")
    writeToFile("/tmp/zjx/show_message.sh",info)
    os.execute("sh /tmp/zjx/show_message.sh")
    return info
end


function main()
    cmd = "ping " .. FixtureControlCore.host .. " -t 1"
    local response = os.execute(cmd)
    if not response then
        show_message(nil,cmd.."fail,请检查网络")
        return 0
    end
    mutexPlugin = Atlas.loadPlugin("MutexPlugin")
    -- /usr/local/Atlas/Plugins/MutexPlugin.l-dylib
    fixtureControlPlugin = Atlas.loadPlugin("MIXRPCRelay")
    FixtureControlCore.init(fixtureControlPlugin, mutexPlugin)
    ret = fileRead("/tmp/FixtureControlCore.txt")
    print(ret,12313123123123)
    print("in===============")
    ret = string.gsub(ret, "\r", "")
    ret = string.gsub(ret, "\n", "")
    ret = string.gsub(ret, " ", "")
    if ret == "release" then
        FixtureControlCore.release()
    elseif ret== "press" then
        FixtureControlCore.press()
    elseif ret =="down" then
        FixtureControlCore.T_down()
    elseif ret =="up" then
        FixtureControlCore.T_up()
    elseif ret== "in" then
        FixtureControlCore.T_in()
    elseif ret =="out" then
        FixtureControlCore.T_out()
    end
end

-- log_close()
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------