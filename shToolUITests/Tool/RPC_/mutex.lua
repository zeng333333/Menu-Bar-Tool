local _mutex = {}

function _mutex.uuid()
    local template ="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    local d = io.open("/dev/urandom", "r"):read(4)
    math.randomseed(os.time() + d:byte(1) + (d:byte(2) * 256) + (d:byte(3) * 65536) + (d:byte(4) * 4294967296))
    return string.gsub(template, "x", function (c)
          local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
          return string.format("%x", v)
          end)
end

function _mutex.runWithLock(plugin, identifier, func, ...)
    local function __inner_run_with_lock(plugin, identifier, func, ...)
        local id = identifier or _mutex.uuid()
        plugin.acquire(id)
        return func(...)
    end

    local status, result = xpcall(__inner_run_with_lock, debug.traceback, plugin, identifier, func, ...)
    plugin.release(identifier)
    if not status then
        error(result)
    end
    return result
end

function _mutex.reset(plugin)
    plugin.reset()
end

function _mutex.isNewIdentifier(plugin, identifier)
    return plugin.isNewIdentifier(identifier)
end

return _mutex