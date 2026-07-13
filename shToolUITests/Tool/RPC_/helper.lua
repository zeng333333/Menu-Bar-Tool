local helper = {}

local LOG_LEVEL_ERROR = 0
local LOG_LEVEL_INFO = 1
local LOG_LEVEL_DEBUG = 2

local LOGGING_THREAD
local MAIN_INDEX
local TECH_INDEX
local THREAD_ID
local TP_ID

local logging_level = LOG_LEVEL_INFO

local ERROR_PREFIX = "ERROR"
local DEBUG_PREFIX = "DEBUG"
local INFO_PREFIX = "INFO"

local TEST_START_PREFIX_FORMAT = "[Test Start][%s-%d-%d][%s][<%s> <%s> <%s>]"
local TEST_PASS_PREFIX_FORMAT = "[Test Pass][%s-%d-%d][%s][<%s> <%s> <%s>]"
local TEST_FAIL_PREFIX_FORMAT = "[Test Fail][%s-%d-%d][%s][<%s> <%s> <%s>]"
local THREAD_LOGGING_PREFIX_FORMAT = "[%s-%d-%d][%s][%s][%s]" -- [identifier-mainIndex-techIndex][thread][file][level]
local LOGGING_PREFIX_FORMAT = "[%s][%s]" -- [file][level]

local function print_r(T)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end
    if (type(T) == "table") then
        print(tostring(T) .. " {")
        sub_print_r(T, "  ")
        print("}")
    else
        sub_print_r(T, "  ")
    end
    print()
end

function helper.setLogEnv(loggingTech, level, id, mainIndex, techIndex, threadID)
    LOGGING_THREAD = loggingTech or false
    logging_level = level or LOG_LEVEL_INFO
    MAIN_INDEX = mainIndex or 0
    TECH_INDEX = techIndex or 0
    THREAD_ID = threadID or nil
    TP_ID = id
    print(LOGGING_THREAD, logging_level, MAIN_INDEX, TECH_INDEX, THREAD_ID, TP_ID)
end

local function _log(...)
    local logString = ""
    local logTable = {}
    for _, element in ipairs({...}) do
        if type(element) == "table" then
            table.insert(logTable, element)
        end
        logString = logString .. tostring(element) .. "  "
    end
    print(logString)
    for _, t in ipairs(logTable) do
        print_r(t)
    end
end

local function log(level, ...)
    local file = string.match(debug.getinfo(3, 'S').short_src, "/([^/]+%.lua)")
    if LOGGING_THREAD then
        _log(string.format(THREAD_LOGGING_PREFIX_FORMAT, TP_ID or "main", MAIN_INDEX or 0, TECH_INDEX or 0,
                           THREAD_ID or "", file, level), ...)
    else
        _log(string.format(LOGGING_PREFIX_FORMAT, file, level), ...)
    end
end
function helper.LogDebug(...)
    if logging_level >= LOG_LEVEL_DEBUG then
        log(DEBUG_PREFIX, ...)
    end
end

function helper.LogError(...)
    if logging_level >= LOG_LEVEL_ERROR then
        log(ERROR_PREFIX, ...)
    end
end

function helper.LogInfo(...)
    if logging_level >= LOG_LEVEL_INFO then
        log(INFO_PREFIX, ...)
    end
end

function helper.LogDutCommFinish(...)
    log(INFO_PREFIX, ...)
end

function helper.LogDutCommStart(...)
    log(INFO_PREFIX, ...)
end

return helper
