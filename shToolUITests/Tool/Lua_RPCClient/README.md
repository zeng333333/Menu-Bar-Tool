# Lua_RPCClient

基于 Lua 的 RPC 客户端测试脚本，面向多设备并行/顺序测试场景，通过 TCP 连接设备并执行 RPC 命令，输出可读日志与结构化测试记录，便于回溯与统计。

## 功能亮点
- 多设备并行调度（协程）或顺序执行
- 可配置测试计划（动作、命令、记录名）
- 连接失败可跳过，失败记录可采样保留
- 结果自动结构化为 CSV
- 表格/日志中的 `table` 返回值自动转 JSON 字符串，避免内存地址样式

## 依赖与环境
- Lua 运行环境
- Atlas 框架（脚本内使用 `Atlas.loadPlugin("MIXRPCRelay")`）
- Python3（用于生成毫秒级时间戳与执行计时）

## Lua 扩展库
本仓库附带 Lua `.so` 扩展库，集中在 `lib/` 目录，并在根目录提供了 `socket-3.1.0.so`。
- 说明与列表：`lib/README.md`
- 新手入门与 Demo：
  - `cjson`：`lib/GETTING_STARTED_CJSON.md` / `lua lib/demo_cjson.lua`
  - `lfs`：`lib/GETTING_STARTED_LFS.md` / `lua lib/demo_lfs.lua`
  - `llthreads`：`lib/GETTING_STARTED_LLTHREADS.md` / `lua lib/demo_llthreads.lua`
  - `socket`：`lib/GETTING_STARTED_SOCKET.md` / `lua lib/demo_socket.lua`

## 目录结构与输出
每次运行会生成独立目录，按设备分开记录：
```
<运行目录>/YYYYMMDD_HHMMSS/<device_note>/
  - panda.log
  - records.csv
```

- `panda.log`：原始文本日志，包含系统信息、发送命令与回读结果
- `records.csv`：结构化测试记录（字段见下）

## 快速运行
在 Atlas 运行环境中执行：
```
AtlasGroupProcess coreless /path/to/Panda.lua
```

## 配置说明
核心配置在 `Panda.lua` 的 `main()` 内：

### 设备列表（`deviceConfig`）
- `note`：设备备注（用于目录名与日志标识，如 `slot5`）
- `serversName`：RPC 服务器名（如 `dut0`）
- `host` / `port`：设备地址
- `timeout`：RPC 超时（毫秒）

### 测试计划（`testPlan`）
每个测试项包含：
- `command`：RPC 命令字符串（例如 `relay.reset(reset)`）
- `action`：执行动作（如 `action.getInfo` / `action.measure` / `action.sleep`）
- `testName`：记录名（写入 `records.csv` 的 `testName` 列；未填默认用 `command`）

示例：
```
local testPlan = {
  {testName = "relay_reset", action = action.getInfo, command = "relay.reset(reset)"},
  {testName = "sleep_5s", action = action.sleep, command = "sleep 5"},
  {testName = "measure_after", action = action.measure, command = "sib_board.lock_xadc_measure(0,0,200)"},
}
```

### 运行参数（`options`）
在 `main()` 中可调整：
- `runMode`：`sequential` 或 `coroutine`（协程并行调度）
- `skipOnConnectError`：连接失败是否跳过该设备
- `maxErrorSamples`：错误样本保留条数

## 记录字段（records.csv）
字段顺序如下：
```
ts,device,testName,command,ok,duration_ms,result,error
```

字段说明：
- `ts`：毫秒级时间戳
- `device`：设备备注（`note`）
- `testName`：测试记录名
- `command`：实际执行命令
- `ok`：是否成功（true/false）
- `duration_ms`：执行耗时（毫秒）
- `result`：成功结果（如为 table 则自动转 JSON）
- `error`：失败错误信息

## 并行与 sleep 行为
协程模式下，`action.sleep` 使用“让出式等待”，避免阻塞其他设备；顺序模式保持阻塞等待。若需要更低 CPU 占用的休眠方式，可替换为 Atlas 或其他运行时提供的 sleep API。

## 常见问题
- `Atlas` 未定义告警：Lua 诊断提示，属于外部运行时注入，可忽略
- 连接失败：检查 `host/port`、设备电源与网络连通性
