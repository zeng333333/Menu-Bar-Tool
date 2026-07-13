local lfs = require("lfs")
local llt = require("llthreads")

-- local function printf(fmt, ...)
--   io.stdout:write(string.format(fmt, ...), "\n")
-- end

-- printf("Lua: %s", _VERSION)
-- printf("lfs version: %s", lfs._VERSION or "unknown")

-- local cwd = lfs.currentdir()
-- printf("current dir: %s", cwd)

-- local script = arg[0] or ""
-- local script_dir = script:match("(.+)/[^/]+$") or "."
-- printf("script dir: %s", script_dir)

-- local attrs, err = lfs.attributes(script_dir)
-- if not attrs then
--   error("failed to stat script dir: " .. tostring(err))
-- end

-- printf("script dir mode: %s", attrs.mode)
-- printf("script dir isdir: %s", tostring(attrs.mode == "directory"))

-- printf("listing script dir:")
-- for name in lfs.dir(script_dir) do
--   if name ~= "." and name ~= ".." then
--     local full = script_dir .. "/" .. name
--     local a = lfs.attributes(full)
--     local mode = a and a.mode or "unknown"
--     local size = a and a.size or 0
--     printf("  - %s (%s, %d bytes)", name, mode, size)
--   end
-- end
