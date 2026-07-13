

local rpc = {}
local logger = {}
logger.deviceFiles = {}
logger.deviceDirs = {}
logger.runDir = nil


local action = {}
_G.action = action
local parse_sleep_seconds
local sleep_seconds

function action.getInfo( paraTab )
	local item = paraTab.testItem
	local device = paraTab.testDevice

	local result, err = rpc.sendRpcCmd(device, item.command)
	if err then
		error(err)
	end
	return result
end

function action.measure( paraTab )
	local item = paraTab.testItem
	local device = paraTab.testDevice

	local result, err = rpc.sendRpcCmd(device, item.command)
	if err then
		error(err)
	end
	result = result + 50
	return result
end

local function now_ms()
	local handle = io.popen([[python3 -c 'import time;print(int(time.time()*1000))']])
	if not handle then
		return os.time() * 1000
	end
	local result = handle:read("*a")
	handle:close()
	local ms = tonumber(result)
	if not ms then
		return os.time() * 1000
	end
	return ms
end

parse_sleep_seconds = function(command)
	if type(command) ~= "string" then
		return 0
	end
	local sec = command:match("sleep%s+(%d+%.?%d*)")
	return tonumber(sec) or 0
end

sleep_seconds = function(seconds, allowYield)
	if seconds <= 0 then
		return
	end
	if allowYield and coroutine.running() then
		local target = now_ms() + seconds * 1000
		while now_ms() < target do
			coroutine.yield()
		end
	else
		os.execute(string.format("sleep %s", tostring(seconds)))
	end
end

function action.sleep( paraTab )
	local item = paraTab.testItem
	local device = paraTab.testDevice

	local seconds = parse_sleep_seconds(item.command)
	sleep_seconds(seconds, false)
	return true
end

function currDir()
	local filePath = debug.getinfo(1, "S").source:sub(2)
	-- print(string.format("filePath: %s", filePath))
	local dirname = filePath:match("(.*/)") or "."
	-- print(string.format("dirname: %s", dirname))
	if dirname == "./" then
		local op = io.popen("pwd"):read("*a")
		local dir = string.sub(op, 1, #op -1)
		return dir
	end
	return dirname
end

function rpc.init( host, port, timeout )
	local rpcPlugin = Atlas.loadPlugin("MIXRPCRelay")
	-- rpcClientObjc.init(host, port)
	local status, result = xpcall(rpcPlugin.commands, debug.traceback, string.format("connect(dut0,tcp://%s:%s)", host, port), timeout)
	if not status then
		return rpcPlugin, result
	end
	return rpcPlugin, nil
end


function rpc.sendRpcCmd( deviceTab, command )
	command = deviceTab.name .. "." .. command
	local status, result = xpcall(deviceTab.rpcPlugin.commands, debug.traceback, command, deviceTab.timeout)
	if not status then
		return nil, string.format("rpc error: %s", result)
	end
	return result, nil
end

-- 使用系统命令获取毫秒时间戳
function getMillisecondTimestamp()
	-- 使用 Python 获取时间戳
	local cmd = [[python3 -c 'from datetime import datetime;print(str(datetime.strftime(datetime.now(), "%Y-%m-%d %H:%M:%S.%f"))[:-3])']]
	local handle = io.popen(cmd)
	if not handle then
		return os.date("%Y-%m-%d %H:%M:%S")
	end
	local result = handle:read("*a")
	handle:close()
	if not result then
		return os.date("%Y-%m-%d %H:%M:%S")
	end
	result = result:gsub("\n", "")
	return result
end

local function json_escape(text)
	text = text:gsub("\\", "\\\\")
	text = text:gsub("\"", "\\\"")
	text = text:gsub("\n", "\\n")
	text = text:gsub("\r", "\\r")
	text = text:gsub("\t", "\\t")
	return text
end

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

local function json_encode(value)
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
		return "\"" .. json_escape(value) .. "\""
	end
	if vtype == "table" then
		if is_array(value) then
			local parts = {}
			for i = 1, #value do
				parts[#parts + 1] = json_encode(value[i])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, v in pairs(value) do
			parts[#parts + 1] = json_encode(tostring(k)) .. ":" .. json_encode(v)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return json_encode(tostring(value))
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

local function safe_tostring(value,flag)
	flag = flag or "" 
	if value == nil then
		return "nil"
	end
	if type(value) == "table" then
		if flag == "json" then
			return json_encode_pro(value)
		else
			return json_encode(value)
		end
	end
	return tostring(value)
end

local function sanitize_name(name)
	local safe = tostring(name or "unknown")
	safe = safe:gsub("[/%s]", "_")
	return safe
end

local function ensure_dir(path)
	os.execute(string.format("mkdir -p \"%s\"", path))
end

local function csv_escape(text)
	local s = safe_tostring(text)
	if s:find("[,\n\r\"]") then
		s = s:gsub("\"", "\"\"")
		return "\"" .. s .. "\""
	end
	return s
end

local function trim(text)
	if not text then
		return ""
	end
	return tostring(text):gsub("^%s+", ""):gsub("%s+$", "")
end

local function split_csv_line(line)
	local fields = {}
	local field = ""
	local in_quotes = false
	local i = 1
	while i <= #line do
		local ch = line:sub(i, i)
		if ch == "\"" then
			if in_quotes and line:sub(i + 1, i + 1) == "\"" then
				field = field .. "\""
				i = i + 1
			else
				in_quotes = not in_quotes
			end
		elseif ch == "," and not in_quotes then
			table.insert(fields, field)
			field = ""
		else
			field = field .. ch
		end
		i = i + 1
	end
	table.insert(fields, field)
	return fields
end

local function load_test_plan(csvPath)
	local file = io.open(csvPath, "r")
	if not file then
		print(string.format("MainTable.csv not found: %s", tostring(csvPath)))
		return {}
	end
	local plan = {}
	local is_header = true
	for line in file:lines() do
		if is_header then
			is_header = false
		else
			local fields = split_csv_line(line)
			local disable = trim(fields[1] or "")
			if disable:upper() ~= "Y" then
				local testName = trim(fields[2] or "")
				local actionName = trim(fields[3] or "")
				local command = trim(fields[4] or "")
				local lowerLimit = trim(fields[5] or "")
				local upperLimit = trim(fields[6] or "")
				local units = trim(fields[7] or "")
				local actionFunc = nil
				local cursor = _G
				local ok = true
				for part in actionName:gmatch("[^%.]+") do
					if type(cursor) == "table" then
						cursor = cursor[part]
					else
						ok = false
						break
					end
				end
				if ok and type(cursor) == "function" then
					actionFunc = cursor
				end
				if actionFunc and command ~= "" then
					table.insert(plan, {
						testName = testName ~= "" and testName or command,
						action = actionFunc,
						command = command,
						lowerLimit = lowerLimit ~= "" and lowerLimit or nil,
						upperLimit = upperLimit ~= "" and upperLimit or nil,
						units = units ~= "" and units or nil
					})
				else
					print(string.format("skip invalid row: action=%s command=%s", actionName, command))
				end
			end
		end
	end
	file:close()
	return plan
end

local function to_number_or_nil(value)
	if value == nil then
		return nil
	end
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		local n = tonumber(value)
		return n
	end
	return nil
end

local function has_value(value)
	return value ~= nil and value ~= ""
end

local function check_limits(measurementValue, lowerLimit, upperLimit)
	if not has_value(lowerLimit) and not has_value(upperLimit) then
		return true, ""
	end

	local m_num = to_number_or_nil(measurementValue)
	local l_num = to_number_or_nil(lowerLimit)
	local u_num = to_number_or_nil(upperLimit)

	if m_num and (l_num or u_num) then
		if l_num and m_num < l_num then
			return false, string.format("below lowerLimit(%s)", tostring(lowerLimit))
		end
		if u_num and m_num > u_num then
			return false, string.format("above upperLimit(%s)", tostring(upperLimit))
		end
		return true, ""
	end

	local m_str = safe_tostring(measurementValue)
	local l_str = has_value(lowerLimit) and safe_tostring(lowerLimit) or ""
	local u_str = has_value(upperLimit) and safe_tostring(upperLimit) or ""

	if l_str ~= "" and u_str ~= "" then
		if m_str == l_str or m_str == u_str then
			return true, ""
		end
		return false, string.format("not in limits(%s|%s)", l_str, u_str)
	end
	if l_str ~= "" then
		return m_str == l_str, string.format("not equal lowerLimit(%s)", l_str)
	end
	if u_str ~= "" then
		return m_str == u_str, string.format("not equal upperLimit(%s)", u_str)
	end
	return true, ""
end

function logger.init_run(runDir, deviceConfig)
	logger.runDir = runDir
	ensure_dir(runDir)
	for _, device in ipairs(deviceConfig) do
		local deviceDir = runDir .. "/" .. sanitize_name(device.note)
		ensure_dir(deviceDir)
		logger.deviceDirs[device.note] = deviceDir

		local logFile, logErr = io.open(deviceDir .. "/panda.log", "a+")
		local csvFile, csvErr = io.open(deviceDir .. "/records.csv", "a+")
		if logFile and csvFile then
			logger.deviceFiles[device.note] = {log = logFile, csv = csvFile}
			local size = csvFile:seek("end")
			if size == 0 then
				csvFile:write("dateTime,device,testName,command,Status,duration_ms,lowerLimit,measurementValue,upperLimit,Units,failureMessage\n")
				csvFile:flush()
			end
		else
			print(string.format("logger init failed for %s: %s %s", tostring(device.note), tostring(logErr), tostring(csvErr)))
		end
	end
end

function logger.write_raw(text, deviceNote)
	if deviceNote then
		local handle = logger.deviceFiles[deviceNote]
		if handle and handle.log then
			handle.log:write(text)
		end
		return
	end
	local wrote = false
	for _, handle in pairs(logger.deviceFiles) do
		if handle.log then
			handle.log:write(text)
			wrote = true
		end
	end
	if not wrote then
		io.stdout:write(text)
	end
end

function logger.write_file(flag, text, deviceNote)
	local ts = getMillisecondTimestamp()
	local logCurrent = string.format("%s %s %s\n", ts, flag, safe_tostring(text))
	logger.write_raw(logCurrent, deviceNote)
end

function logger.LogInfo(text)
	logger.write_file("<post--info>[system]:", text)
end

function logger.LogSenCmd(text, process)
	logger.write_file(string.format("<post---send>[%s]:", process), text, process)
end

function logger.LogReadCmd(text, process)
	logger.write_file(string.format("<post-result>[%s]:", process), text, process)
end

function logger.WriteRecord(deviceNote, record)
	local handle = logger.deviceFiles[deviceNote]
	if not handle or not handle.csv then
		return
	end
	local line = table.concat({
		csv_escape(record.dateTime),
		csv_escape(record.device),
		csv_escape(record.testName),
		csv_escape(record.command),
		csv_escape(record.status),
		csv_escape(record.duration_ms),
		csv_escape(record.lowerLimit),
		csv_escape(record.measurementValue),
		csv_escape(record.upperLimit),
		csv_escape(record.units),
		csv_escape(record.failureMessage)
	}, ",") .. "\n"
	handle.csv:write(line)
end

function logger.close()
	for _, handle in pairs(logger.deviceFiles) do
		if handle.log then
			handle.log:close()
		end
		if handle.csv then
			handle.csv:close()
		end
	end
end

function start_test(deviceConfig, options)
	local time = os.date("%Y%m%d_%H%M%S", os.time())
	local curr_dir = currDir()
	print(string.format("curr_dir:%s", curr_dir))
	if curr_dir:sub(-1) ~= "/" then
		curr_dir = curr_dir .. "/"
	end
	local run_dir = string.format("%slog/%s", curr_dir, time)
	logger.init_run(run_dir, deviceConfig)
	logger.LogInfo("START TEST\n")
	logger.LogInfo(string.format("RUN MODE: %s", options and options.runMode or "sequential"))
end

function stop_test()
	logger.LogInfo("STOP TEST")
	logger.close()
end


local function init_stats()
	return {
		total = 0,
		ok = 0,
		fail = 0,
		devices = {},
		deviceIndex = {}
	}
end

local function get_device_stats(stats, deviceNote)
	local ds = stats.deviceIndex[deviceNote]
	if not ds then
		ds = {device = deviceNote, total = 0, ok = 0, fail = 0, duration_ms = 0, errors = {}}
		stats.deviceIndex[deviceNote] = ds
		table.insert(stats.devices, ds)
	end
	return ds
end

local function exec_item(device, item, stats, options)
	local deviceStats = get_device_stats(stats, device.note)
	local start_ms = now_ms()
	stats.total = stats.total + 1
	deviceStats.total = deviceStats.total + 1

	logger.LogSenCmd(item.command, device.note)
	local ok = true
	local result
	if item.action == action.sleep then
		local seconds = parse_sleep_seconds(item.command)
		sleep_seconds(seconds, options.runMode == "coroutine")
		result = true
	else
		ok, result = xpcall(item.action, debug.traceback, {testItem = item, testDevice = device})
	end
	local duration_ms = now_ms() - start_ms
	deviceStats.duration_ms = deviceStats.duration_ms + duration_ms

	if ok then
		local pass, reason = check_limits(result, item.lowerLimit, item.upperLimit)
		local status = pass and "PASS" or "FAIL"
		if pass then
			stats.ok = stats.ok + 1
			deviceStats.ok = deviceStats.ok + 1
		else
			stats.fail = stats.fail + 1
			deviceStats.fail = deviceStats.fail + 1
		end
		logger.LogReadCmd(safe_tostring(result,"json"), device.note)
		logger.WriteRecord(device.note, {
			dateTime = getMillisecondTimestamp(),
			device = device.note,
			testName = item.testName or item.command,
			command = item.command,
			status = status,
			duration_ms = duration_ms,
			lowerLimit = item.lowerLimit or "",
			measurementValue = safe_tostring(result),
			upperLimit = item.upperLimit or "",
			units = item.units or "",
			failureMessage = pass and "" or reason
		})
	else
		stats.fail = stats.fail + 1
		deviceStats.fail = deviceStats.fail + 1
		logger.LogReadCmd("error: " .. safe_tostring(result), device.note)
		logger.WriteRecord(device.note, {
			dateTime = getMillisecondTimestamp(),
			device = device.note,
			testName = item.testName or item.command,
			command = item.command,
			status = "FAIL",
			duration_ms = duration_ms,
			lowerLimit = item.lowerLimit or "",
			measurementValue = safe_tostring(result) or "",
			upperLimit = item.upperLimit or "",
			units = item.units or "",
			failureMessage = safe_tostring(result)
		})
		if #deviceStats.errors < (options.maxErrorSamples or 3) then
			table.insert(deviceStats.errors, safe_tostring(result))
		end
	end
end

local function run_sequential(devicePlugin, testPlan, stats, options)
	for _, device in ipairs(devicePlugin) do
		for _, item in ipairs(testPlan) do
			exec_item(device, item, stats, options)
		end
	end
end

local function run_coroutine(devicePlugin, testPlan, stats, options)
	local workers = {}
	for _, device in ipairs(devicePlugin) do
		workers[#workers + 1] = coroutine.create(function()
			for _, item in ipairs(testPlan) do
				exec_item(device, item, stats, options)
				coroutine.yield()
			end
		end)
	end
	local running = true
	while running do
		running = false
		for _, co in ipairs(workers) do
			if coroutine.status(co) ~= "dead" then
				running = true
				coroutine.resume(co)
			end
		end
	end
end

local function log_summary(stats)
	logger.LogInfo(string.format("SUMMARY total=%d ok=%d fail=%d", stats.total, stats.ok, stats.fail))
end

function sequence(deviceConfig, testPlan, options)
	options = options or {}
	if not options.runMode then
		options.runMode = "sequential"
	end

	local devicePlugin = {}
	for i, device in ipairs(deviceConfig) do
		local rpcPlugin, connectErr = rpc.init(device.host, device.port, device.timeout)
		devicePlugin[i] = {
							["rpcPlugin"] = rpcPlugin, 
							["name"] = device.serversName,
							["note"] = device.note,
							["timeout"] = device.timeout,
							["connectError"] = connectErr
						}
	end

	local stats = init_stats()
	local runnable = {}
	for _, device in ipairs(devicePlugin) do
		if device.connectError and options.skipOnConnectError ~= false then
			local deviceStats = get_device_stats(stats, device.note)
			deviceStats.fail = deviceStats.fail + #testPlan
			stats.fail = stats.fail + #testPlan
			logger.LogReadCmd("connect error: " .. safe_tostring(device.connectError), device.note)
			logger.WriteRecord(device.note, {
				dateTime = getMillisecondTimestamp(),
				device = device.note,
				testName = "connect",
				command = "connect",
				status = "FAIL",
				duration_ms = 0,
				lowerLimit = "",
				measurementValue = "",
				upperLimit = "",
				units = "",
				failureMessage = safe_tostring(device.connectError)
			})
		else
			table.insert(runnable, device)
		end
	end

	if options.runMode == "coroutine" then
		run_coroutine(runnable, testPlan, stats, options)
	else
		run_sequential(runnable, testPlan, stats, options)
	end
	log_summary(stats)
	return stats
end

function main()
	local deviceConfig = {
		-- {note = "slot1", serversName = "dut0", host = "192.168.99.32", port = "7801", timeout = 2000},
		-- {note = "slot2", serversName = "dut0", host = "192.168.99.33", port = "7801", timeout = 2000},
		-- {note = "slot3", serversName = "dut0", host = "192.168.99.34", port = "7801", timeout = 2000},
		-- {note = "slot4", serversName = "dut0", host = "192.168.99.35", port = "7801", timeout = 2000},
		-- {note = "slot5", serversName = "dut0", host = "192.168.99.36", port = "7801", timeout = 2000},
		-- {note = "slot6", serversName = "dut0", host = "192.168.99.37", port = "7801", timeout = 2000},
		-- {note = "slot7", serversName = "dut0", host = "192.168.99.38", port = "7801", timeout = 2000},
		{note = "slot8", serversName = "dut0", host = "192.168.99.39", port = "7801", timeout = 2000},
	}

	local testPlan = {}

	local options = {
		runMode = "coroutine",
		skipOnConnectError = true,
		maxErrorSamples = 3
	}

	local curr_dir = currDir()
	if curr_dir:sub(-1) ~= "/" then
		curr_dir = curr_dir .. "/"
	end
	testPlan = load_test_plan(curr_dir .. "MainTable.csv")

	start_test(deviceConfig, options)
	sequence(deviceConfig, testPlan, options)
	stop_test()
end




-- AtlasGroupProcess coreless /path/to/my/sequence.lua






