------------------------------------------------------------------------------------------------------------------------------------------
-- FixtureControlDebug.lua
-- 基于 FixtureControl.l-dylib 插件的串口调试脚本
-- 用法: 将指令写入 /tmp/FixtureControlDebug.txt 后运行本脚本
--       或直接 AtlasGroupProcess coreless ./FixtureControlDebug.lua 进入交互模式
------------------------------------------------------------------------------------------------------------------------------------------
local fc = nil
local PLUGIN_NAME = "FixtureControl_SC"

------------------------------------------------------------------ Common ------------------------------------------------------------------
function show_message(title, message)
    local title = title or "提示"
    local message = message or ""
    local info = string.format('osascript -e \'display alert "%s" message "%s" as critical\'', title, message)
    os.execute('mkdir -p /tmp/zjx;touch /tmp/zjx/show_message.sh;rm /tmp/zjx/show_message.sh')
    local file = io.open("/tmp/zjx/show_message.sh", "w")
    if file then file:write(info); file:close() end
    os.execute("sh /tmp/zjx/show_message.sh")
end

function fileRead(path)
    if not path then return nil end
    local file = io.open(path, "r")
    if file then
        local data = file:read("*all")
        file:close()
        return data
    end
    return ""
end

function trim(s)
    s = string.gsub(s, "^[\r\n%s]+", "")
    s = string.gsub(s, "[\r\n%s]+$", "")
    return s
end

function printResult(title, ret)
    print(string.format("[%s] => %s", title, tostring(ret)))
end

------------------------------------------------------------------ Actions ------------------------------------------------------------------
local DEFAULT_PORT = "/dev/cu.usbserial-ECB"
--local DEFAULT_PORT = "/dev/ttys008"

function action_init(portPath)
    local port = portPath or DEFAULT_PORT
    local ret = fc.fixture_init(port)
    printResult("fixture_init " .. port, ret)
    return ret
end

function action_in()
    local ret = fc.fixture_in()
    printResult("fixture_in (press)", ret)
    return ret
end

function action_out()
    local ret = fc.fixture_out()
    printResult("fixture_out (release)", ret)
    return ret
end

function action_startbutton()
    local ret = fc.fixture_startbutton_check()
    printResult("fixture_startbutton_check", ret)
    return ret
end

function action_close()
    local ret = fc.close()
    printResult("close", ret)
    return ret
end

function action_send(cmd)
    local ret = fc.fixture_send(cmd)
    printResult(cmd, ret)
    return ret
end

function action_set_led(slotStr, color)
    local slot = tonumber(slotStr)
    if not slot or slot < 1 or slot > 8 then
        show_message("LED错误", "slot 必须是 1-8 的数字")
        return
    end
    local validColors = {R=true, G=true, B=true, Y=true}
    if not validColors[color] then
        show_message("LED错误", "color 必须是 R/G/B/Y")
        return
    end
    local ret = fc.fixture_set_led(slot, color)
    printResult(string.format("LED%03d,%s", slot, color), ret)
    return ret
end

function action_led_reset()
    local ret = fc.fixture_led_reset()
    printResult("LED reset", ret)
    return ret
end

function action_read_sensors()
    local sensors = {"in?", "out?", "down?", "up?", "frontsensor?", "rearsensor?"}
    print("========== 传感器状态 ==========")
    for _, cmd in ipairs(sensors) do
        local ret = fc.fixture_send(cmd)
        print(string.format("  %-15s => %s", cmd, tostring(ret)))
    end
    print("=================================")
end

------------------------------------------------------------------ Command Dispatch ------------------------------------------------------------------
function dispatch(cmd)
    cmd = trim(cmd)
    if cmd == "" then return end

    if cmd == "init" then
        action_init()
    elseif string.sub(cmd, 1, 5) == "init " then
        local portPath = string.sub(cmd, 6)
        action_init(portPath)
    elseif cmd == "in" then
        action_send("in")
    elseif cmd == "down" then
        action_send("down")
    elseif cmd == "press" then
        action_in()
    elseif cmd == "out" then
        action_send("out")
    elseif cmd == "up" then
        action_send("up")
    elseif cmd == "release" then
        action_out()
    elseif cmd == "startbutton" then
        action_startbutton()
    elseif cmd == "close" then
        action_close()
    elseif cmd == "ledreset" then
        action_led_reset()
    elseif cmd == "read" or cmd == "sensors" then
        action_read_sensors()
    elseif cmd == "version" then
        action_send("version")
    elseif cmd == "help" then
        action_send("help")
    elseif cmd == "reset" then
        action_send("reset")
    elseif string.sub(cmd, 1, 4) == "led " then
        -- 格式: led 1 R  或  led 3 G
        local rest = string.sub(cmd, 5)
        local slotStr, color = string.match(rest, "(%d+)%s+([RGBY])")
        if slotStr and color then
            action_set_led(slotStr, color)
        else
            show_message("LED格式错误", "用法: led <1-8> <R/G/B/Y>")
        end
    elseif string.sub(cmd, 1, 5) == "send " then
        -- 格式: send frontsensor?
        local rawCmd = string.sub(cmd, 6)
        action_send(rawCmd)
    else
        -- 未知指令，直接作为串口指令发送
        action_send(cmd)
    end
end

------------------------------------------------------------------ Main ------------------------------------------------------------------
function printHelp()
    print("========== FixtureControl 调试命令 ==========")
    print("  init [port]       初始化串口（默认 /dev/cu.usbserial-ECB）")
    print("  in                单步进入")
    print("  down              单步下压")
    print("  press             组合动作：进入+下压（带轮询）")
    print("  out               单步出来")
    print("  up                单步上升")
    print("  release           组合动作：上升+推出（带轮询）")
    print("  startbutton       检测开始按钮")
    print("  close             关闭串口")
    print("  led <1-8> <R/G/B/Y>  设置通道LED")
    print("  ledreset          复位全部LED")
    print("  read / sensors    读取全部传感器状态")
    print("  version           查询FW版本")
    print("  help              查询电控板指令列表")
    print("  reset             复位LED")
    print("  send <cmd>       发送任意串口指令")
    print("  in?/out?/down?/up?/frontsensor?/rearsensor?  查询单个传感器")
    print("  exit              退出交互模式")
    print("============================================")
end

function main()
    -- 加载插件
    fc = Atlas.loadPlugin(PLUGIN_NAME)
    if not fc then
        show_message("加载失败", "无法加载插件: " .. PLUGIN_NAME)
        return
    end
    print("插件 " .. PLUGIN_NAME .. " 加载成功")

    action_init()
    single_flag = "false"
    --  从文件读取指令
    local cmdFile = "/tmp/FixtureControlCore.txt"
    local fileCmd = fileRead(cmdFile)
    if fileCmd and trim(fileCmd) ~= "" then
        single_flag = "true"
        print(single_flag,"single_flag")
        -- 文件模式：执行文件中的指令后退出
        dispatch(fileCmd)
        os.remove(cmdFile)
        return
    end
    print(single_flag,"single_flag")
    if single_flag =="false" then
        -- 交互模式
        printHelp()


        while true do
            io.write("\n> ")
            io.flush()
            local input = io.read("*line")
            if not input then break end
            input = trim(input)
            if input == "" then
                -- skip
            elseif input == "exit" or input == "quit" then
                action_close()
                break
            elseif input == "help" or input == "?" then
                printHelp()
            else
                dispatch(input)
            end
        end
    end
end

--main()
