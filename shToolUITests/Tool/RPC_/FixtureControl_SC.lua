------------------------------------------------------------------------------------------------------------------------------------------
-- FixtureControlDebug.lua
-- 基于 FixtureControl.l-dylib 插件的串口调试脚本
-- 用法: 将指令写入 /tmp/FixtureControlDebug.txt 后运行本脚本
--       或直接 AtlasGroupProcess coreless ./FixtureControlDebug.lua 进入交互模式
------------------------------------------------------------------------------------------------------------------------------------------
local fc = nil
local PLUGIN_NAME = "FixtureControl_SC"
local single_flag = "false"
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
-- local DEFAULT_PORT = "/dev/ttys008"

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

-- 简单按 \n 切分字符串（返回数组），不依赖环境是否内置 string.split
local function splitLines(s)
    local lines = {}
    if not s then return lines end
    for line in (s .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

-- MIX8 多设备并行二维码解码。
-- decode_mix8(control) 返回纯文本，每台设备一行：
--     "<设备号>:<状态>[:<内容>]"    （状态: OK / FAIL_CONN / FAIL_DECODE / FAIL_TIMEOUT）
-- 这里把文本切成 Lua 的"自然表"（按设备号索引），便于直接访问。
function action_decode_mix8(control)
    local ctrl = control or "1*2*3*4*5*6*7*8"
    print("decode_mix8 开始(真实并行): " .. ctrl)
    -- fc = Atlas.loadPlugin(FixtureControl_SC)
    local ret = fc.decode_mix8(ctrl)
    print(single_flag)
    if single_flag == "true" then
        io.write("\n> ")
        io.flush()
        local input = io.read("*line")
    end
    -- printResult("decode_mix8 " .. ctrl)

    -- local table_out = {}
    -- for _, line in ipairs(splitLines(ret)) do
    --     local no, state, content = string.match(line or "", "^(%-?%d+):([^:]*):?(.*)$")
    --     if no and state then
    --         local idx = tonumber(no)
    --         table_out[idx] = (state == "OK")
    --             and { ok = true,                    content = (content or "") }
    --             or  { ok = false, error = state,    content = (content or "") }
    --     end
    -- end

    -- print("decode_mix8 Lua 表(按设备号索引):")
    -- for i = 1, 8 do
    --     local v = table_out[i]
    --     if v then
    --         print(string.format("  device %d => ok=%s  %s%s",
    --             i, tostring(v.ok),
    --             (v.error and (v.error .. "  ") or ""),
    --             (v.content and v.content or "")))
    --     end
    -- end
    return table_out
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
    elseif cmd == "mix8" then
        action_decode_mix8("1*2*3*4*5*6*7*8")
    elseif string.sub(cmd, 1, 12) == "decode_mix8 " then
        -- 格式: decode_mix8 1*3*5
        action_decode_mix8(string.sub(cmd, 12))
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
    print("  mix8             并行解码全部 8 台 MIX8 二维码 (decode_mix8 1*2*3*)")
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
