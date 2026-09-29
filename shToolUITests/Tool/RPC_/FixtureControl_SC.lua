------------------------------------------------------------------------------------------------------------------------------------------
-- FixtureControl_SC.lua
-- FixtureControl 治具控制调试工具（单文件）
--
-- 用途：验证 FixtureControl_SC.l-dylib 插件（串口治具控制 + 多通道并行 RPC），
--       作为治具控制的调试 Tool 使用。直接跑：
--           AtlasGroupProcess coreless ./FixtureControl_SC.lua
--       或 ./FixtureControl_SC
--
-- 两种模式：
--   1) 单条指令模式：把指令写进 /tmp/FixtureControlCore.txt，脚本启动时读取执行后退出
--   2) 交互模式：不写该文件时进入，逐行敲指令
--
-- 注意：本文件是"调试工具"，真实产线流程用的是 Atlas2 那边的
--       debug/Atlas2/Modules/GroupFunctions.lua（resetFixture）。
------------------------------------------------------------------------------------------------------------------------------------------

local fc = nil
local PLUGIN_NAME = "FixtureControl_SC"

------------------------------------------------------------------ 常量 ------------------------------------------------------------------

-- 默认串口（真实电控板）。虚拟串口调试时改成 uart_debug_Virtual.py 打印的 /dev/ttysXXX。
local DEFAULT_PORT = "/dev/cu.usbserial-ECB"
-- local DEFAULT_PORT = "/dev/ttys008"

-- MIX8 拓扑配置文件路径（读取各 slot 的 Xavier IP/Port）；可按需改成实际路径。
-- 若配置不可读，dylib 侧会自动退回内置默认地址（不会因此报错）。
local MIX8_CONFIG = "/Users/gdlocal/Library/Atlas2/SupportFiles/StationTopology.plist"

-- 单条指令模式的输入文件（由外壳脚本/上层流程写入）。
local CMD_FILE = "/tmp/FixtureControlCore.txt"

-- 8 通道全选控制串。
local ALL_CHANNELS = "1*2*3*4*5*6*7*8"

-- 连通性测试默认参数。
local CONN_DEFAULT_CMD        = "mixdevice.reset_all"
local CONN_DEFAULT_TIMEOUT_MS = 5000

-- 并行 RPC 返回文本里的状态码（与 dylib 侧 Mix8Decoder.mm / ConnectivityTester.mm 对应）。
local STATE = {
    OK          = "OK",             -- 成功 / 通道可用
    CONN_FAIL   = "FAIL_CONN",      -- RPC 服务连不上
    DECODE_FAIL = "FAIL_DECODE",    -- 二维码：连上了但解码失败
    CMD_FAIL    = "FAIL_CMD",       -- 连通性：连上了但初始化指令失败
    TIMEOUT     = "FAIL_TIMEOUT",   -- 超时
}

------------------------------------------------------------------ 通用工具 ------------------------------------------------------------------

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
    if s == nil then return "" end
    s = string.gsub(s, "^[\r\n%s]+", "")
    s = string.gsub(s, "[\r\n%s]+$", "")
    return s
end

function printResult(title, ret)
    print(string.format("[%s] => %s", title, tostring(ret)))
end

--- 按 \n 切分字符串，返回数组（不依赖环境是否内置 string.split）。
local function splitLines(s)
    local lines = {}
    if not s then return lines end
    for line in (s .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

--- 把通道号数组拼成 "1*3*5" 形式（元素之间用 * 连接）。
local function joinChannels(list)
    local parts = {}
    for _, n in ipairs(list or {}) do
        table.insert(parts, tostring(n))
    end
    return table.concat(parts, "*")
end

--- 通道号数组 -> 可读文本，空时返回 "(无)"。
local function listText(list)
    if not list or #list == 0 then return "(无)" end
    local parts = {}
    for _, n in ipairs(list) do
        table.insert(parts, tostring(n))
    end
    return table.concat(parts, ", ")
end

------------------------------------------------------------------ 串口 / 治具动作 ------------------------------------------------------------------

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

------------------------------------------------------------------ 并行 RPC：文本协议解析 ------------------------------------------------------------------

--- 解析 dylib 返回的 "<通道号>:<状态>[:<详情>]" 多行文本。
--- @return table 按通道号索引：{ [1] = { no=1, state="OK", detail="", ok=true }, ... }
---                另带 .list 数组保留原始顺序。
local function parseResultLines(text)
    local out = { list = {} }
    for _, line in ipairs(splitLines(text)) do
        local no, state, detail = string.match(line or "", "^(%-?%d+):([^:]*):?(.*)$")
        if no and state then
            local item = {
                no     = tonumber(no),
                state  = state,
                detail = detail or "",
                ok     = (state == STATE.OK),
            }
            out[item.no] = item
            table.insert(out.list, item)
        end
    end
    return out
end

--- 按状态筛选出通道号数组。
local function channelsWithState(parsed, state)
    local hit = {}
    for _, it in ipairs(parsed and parsed.list or {}) do
        if it.state == state then table.insert(hit, it.no) end
    end
    return hit
end

------------------------------------------------------------------ 并行二维码解码 ------------------------------------------------------------------

-- MIX8 多设备并行二维码解码。
-- decode_mix8(control, configPath) 返回纯文本，每台设备一行：
--     "<设备号>:<状态>[:<内容>]"    （状态: OK / FAIL_CONN / FAIL_DECODE / FAIL_TIMEOUT）
-- configPath: 拓扑 plist（StationTopology.plist）路径，读取每个 slot 的 Xavier IP/Port；传 nil/空则用内置默认。
-- 这里把文本切成 Lua 的"自然表"（按设备号索引），便于直接访问。
function action_decode_mix8(control, configPath)
    local ctrl = control
    if ctrl == nil or trim(ctrl) == "" then ctrl = ALL_CHANNELS end
    local cfg  = configPath or MIX8_CONFIG

    print("decode_mix8 开始(真实并行): " .. ctrl .. "  cfg=" .. tostring(cfg))
    local ret = fc.decode_mix8(ctrl, cfg or "")
    printResult("decode_mix8 " .. ctrl, ret)

    return parseResultLines(ret)
end

--- 打印并行二维码结果（人眼可读）。
local function printDecodeResult(parsed)
    for _, it in ipairs(parsed and parsed.list or {}) do
        if it.ok then
            print(string.format("  通道 %d => OK  %s", it.no, it.detail))
        else
            print(string.format("  通道 %d => %s  %s", it.no, it.state, it.detail))
        end
    end
end

------------------------------------------------------------------ 连通性测试（新增） ------------------------------------------------------------------

-- 并行连通性测试：正式跑流程前先探一遍所有通道，回答三个问题：
--   1. 哪些通道的 RPC 服务连不上？          -> connFail
--   2. 哪些通道通了但初始化指令失败/超时？   -> cmdFail / timeout
--   3. 哪些通道没问题，可以后续使用？        -> okList
--
-- action_connectivity_test(cfgPath, initCmd, timeoutMs)
--   cfgPath   拓扑 plist 路径（读取所有通道的 IP 和端口）；nil/空 = 用 MIX8_CONFIG
--   initCmd   初始化指令，形如 "mixdevice.reset_all"；nil/空 = 用默认
--   timeoutMs 单通道超时（毫秒）；nil/空 = 5000
--
-- 返回汇总表：
--   .ok            boolean 是否所有通道都 OK（且通道数 > 0）
--   .total         number  参与测试的通道数
--   .okList        table   没问题的通道号数组，如 {1, 3, 7, 8}
--   .failList      table   有问题的通道号数组（连不上+指令失败+超时），如 {2, 4, 5, 6}
--   .connFail      table   RPC 服务连不上的通道号数组，如 {4, 5}
--   .cmdFail       table   连上了但初始化指令失败的通道号数组，如 {2}
--   .timeout       table   初始化指令超时的通道号数组，如 {6}
--   .channels      table   按通道号索引的明细（含失败原因 detail）
--   .usableControl string  由 okList 拼成的控制串，如 "1*3*7*8"，可直接喂给并行接口
function action_connectivity_test(cfgPath, initCmd, timeoutMs)
    local cfg = cfgPath
    if cfg == nil or trim(cfg) == "" then cfg = MIX8_CONFIG end

    local cmd = trim(initCmd or "")
    if cmd == "" then cmd = CONN_DEFAULT_CMD end

    local tmo = tonumber(timeoutMs) or CONN_DEFAULT_TIMEOUT_MS
    if tmo <= 0 then tmo = CONN_DEFAULT_TIMEOUT_MS end

    print("==============================================")
    print("连通性测试开始 (并行)")
    print("  拓扑配置: " .. tostring(cfg))
    print("  初始化指令: " .. cmd)
    print("  超时时间: " .. tostring(tmo) .. " ms")
    print("==============================================")

    local ret = fc.connectivity_test(cfg or "", cmd, tmo)
    local parsed = parseResultLines(ret)

    local summary = {
        channels   = parsed,
        total      = #parsed.list,
        okList     = channelsWithState(parsed, STATE.OK),
        connFail   = channelsWithState(parsed, STATE.CONN_FAIL),
        cmdFail    = channelsWithState(parsed, STATE.CMD_FAIL),
        timeout    = channelsWithState(parsed, STATE.TIMEOUT),
        decodeFail = channelsWithState(parsed, STATE.DECODE_FAIL),
    }

    -- 失败通道汇总 = 除 OK 以外的全部通道，按通道号升序。
    local fail = {}
    for _, it in ipairs(parsed.list) do
        if not it.ok then table.insert(fail, it.no) end
    end
    table.sort(fail)
    summary.failList = fail

    summary.usableControl = joinChannels(summary.okList)
    summary.ok = (#fail == 0 and summary.total > 0)

    printConnectivitySummary(summary)
    return summary
end

--- 打印连通性测试汇总（按关心的三个问题分组）。
function printConnectivitySummary(summary)
    print("=============== 连通性测试结果 ===============")
    print(string.format("  参与测试通道: %d 个", summary.total or 0))
    print("")
    print(string.format("  [可正常使用] %d 个通道: %s",
        #(summary.okList or {}), listText(summary.okList)))
    print(string.format("  [连通失败]   %d 个通道: %s",
        #(summary.failList or {}), listText(summary.failList)))
    print("    ├─ RPC连不上   : " .. listText(summary.connFail))
    print("    ├─ 初始化失败  : " .. listText(summary.cmdFail))
    print("    └─ 初始化超时  : " .. listText(summary.timeout))
    print("")

    -- 逐通道明细，方便排查具体是哪台机器、什么原因。
    print("  ---- 通道明细 ----")
    for _, it in ipairs((summary.channels and summary.channels.list) or {}) do
        print(string.format("    通道 %-2d => %-13s %s", it.no, it.state, it.detail or ""))
    end
    print("")

    if summary.ok then
        print("  结论: 全部通道连通，可以开始测试流程。")
    elseif #(summary.okList or {}) > 0 then
        print(string.format("  结论: %d 个通道可用（%s），其余请先排查。",
            #summary.okList, summary.usableControl))
    else
        print("  结论: 没有任何通道可用，请检查网络/服务是否启动。")
    end
    print("==============================================")
end

--- 把汇总表序列化成一行文本（不依赖 json 库，便于写日志或回传上层）。
function connectivitySummaryToText(summary)
    local function nums(list)
        if not list or #list == 0 then return "" end
        return table.concat(list, ",")
    end
    return string.format(
        "total=%d ok=[%s] fail=[%s] conn_fail=[%s] cmd_fail=[%s] timeout=[%s] usable=%s",
        summary.total or 0,
        nums(summary.okList),
        nums(summary.failList),
        nums(summary.connFail),
        nums(summary.cmdFail),
        nums(summary.timeout),
        (summary.usableControl ~= "" and summary.usableControl) or "none")
end

------------------------------------------------------------------ Command Dispatch ------------------------------------------------------------------

function dispatch(cmd)
    cmd = trim(cmd)
    if cmd == "" then return end

    -- ---------------- 串口 / 治具 ----------------
    if cmd == "init" then
        action_init()
    elseif string.sub(cmd, 1, 5) == "init " then
        action_init(string.sub(cmd, 6))
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
        action_send(string.sub(cmd, 6))

    -- ---------------- 并行 RPC ----------------
    elseif cmd == "mix8" then
        action_decode_mix8(ALL_CHANNELS, MIX8_CONFIG)
    elseif string.sub(cmd, 1, 12) == "decode_mix8 " then
        -- 格式: decode_mix8 1*3*5
        --       decode_mix8 1*3*5 /path/to/StationTopology.plist
        local rest = trim(string.sub(cmd, 12))
        local ctrl, cfgPath = string.match(rest, "^(%S+)%s+(%S.*)$")
        if ctrl and cfgPath then
            action_decode_mix8(trim(ctrl), trim(cfgPath))
        else
            action_decode_mix8(rest, MIX8_CONFIG)
        end

    -- ---------------- 连通性测试 ----------------
    elseif cmd == "conn" or cmd == "connectivity" then
        action_connectivity_test(MIX8_CONFIG, CONN_DEFAULT_CMD, CONN_DEFAULT_TIMEOUT_MS)
    elseif string.sub(cmd, 1, 5) == "conn " then
        -- 格式: conn [plist] [初始化指令] [超时ms]
        --   conn                                         -> 全默认
        --   conn /path/to/StationTopology.plist          -> 指定拓扑
        --   conn /path/plist mixdevice.reset_all         -> 指定拓扑+指令
        --   conn /path/plist mixdevice.reset_all 8000    -> 再指定超时
        local parts = {}
        for piece in string.gmatch(trim(string.sub(cmd, 6)), "%S+") do
            table.insert(parts, piece)
        end
        action_connectivity_test(parts[1] or MIX8_CONFIG,
                                 parts[2] or CONN_DEFAULT_CMD,
                                 parts[3] or CONN_DEFAULT_TIMEOUT_MS)

    else
        -- 未知指令，直接作为串口指令发送
        action_send(cmd)
    end
end

------------------------------------------------------------------ Main ------------------------------------------------------------------

function printHelp()
    print("========== FixtureControl 调试命令 ==========")
    print("  --- 串口 / 治具 ---")
    print("  init [port]       初始化串口（默认 " .. DEFAULT_PORT .. "）")
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
    print("  send <cmd>        发送任意串口指令")
    print("  --- 并行 RPC（多通道）---")
    print("  mix8              并行解码全部 8 台 MIX8 二维码")
    print("  decode_mix8 <ctrl> [plist]   指定通道并行解码，如 decode_mix8 1*3*5")
    print("  conn [plist] [cmd] [ms]      并行连通性测试（默认 mixdevice.reset_all / 5000ms）")
    print("  --- 其它 ---")
    print("  in?/out?/down?/up?/frontsensor?/rearsensor?  查询单个传感器")
    print("  exit              退出交互模式")
    print("=============================================")
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

    -- 从文件读取指令（单条模式）
    local fileCmd = fileRead(CMD_FILE)
    if fileCmd and trim(fileCmd) ~= "" then
        print("true", "single_flag")
        dispatch(fileCmd)
        os.remove(CMD_FILE)
        return
    end

    print("false", "single_flag")
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

main()
