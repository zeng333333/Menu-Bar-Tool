-- for normal run
local home = os.getenv('HOME')
if home then
    package.cpath = package.cpath .. ';' .. home .. '/Library/Atlas2/Modules/Mooncake/?.so;'
end

-- for mink test
local cffixedHome = os.getenv('CFFIXED_USER_HOME')
if cffixedHome then
    package.cpath = package.cpath .. ';' .. cffixedHome .. '/Library/Atlas2/Modules/Mooncake/?.so;'
end
local mooncake_0 = require('mooncake_0')

local M = {}


function M.failsafe_schema(scalar)
    return scalar
end

-- json_schema is lenient in terms of number formats
-- json_schema doesn't fail on unquoted strings
-- See https://yaml.org/spec/1.2.2/#102-json-schema for discrepencies
function M.json_schema(scalar)
    if scalar == 'null' then return nil end

    if scalar == 'false' then return false end
    if scalar == 'true' then return true end

    local value = math.tointeger(scalar) or tonumber(scalar)
    if value ~= nil then return value end

    if scalar == '.nan' then return 0/0 end
    if scalar == '.inf' then return 1/0 end
    if scalar == '-.inf' then return -1/0 end

    return scalar
end

function M.core_schema(scalar)
    local scalar_ = scalar:lower()
    local scalar__ = M.json_schema(scalar_)

    if scalar__ ~= scalar_ then return scalar__ end

    if scalar_ == '~' then return nil end

    -- Octal
    local value = scalar_:match('^0o([0-7]+)$')
    if value ~= nil then return math.tointeger(string.format('%o', value)) end

    return scalar
end

M.callback_registry = {}
M.is_allowed_callback_type = {
    diag_output = true,
    node_mapping_sort = true,
    node_meta_clear = true,
    node_scalar_compare = true,
    parser_input = true,

    test = true
}

function M:register_callback(self, name, callback_type, callback)
    if self.has_registry_been_registered == nil then
        mooncake_0.register_callback_registry(self.callback_registry)
        self.has_registry_been_registered = true
    end

    if not self.is_allowed_callback_type[callback_type] then
        error('Unknown callback_type "' .. callback_type .. '"')
    end
    if self.callback_registry[name] ~= nil then
        error('Callback already registered with name "' .. name .. '"')
    end

    mooncake_0.register_callback(name, callback_type)
    self.callback_registry[name] = { callback = callback, callback_type = callback_type }
end

function M:unregister_callback(self, name)
    if not self.has_registry_been_registered then
        error('Callback registry has not been registered')
    end

    if self.callback_registry[name] == nil then
        error('No callback registered with name "' .. name .. '"')
    end

    mooncake_0.unregister_callback(name)
    self.callback_registry[name] = nil
end

function M:readFile(path, schema)
    schema = schema or M.core_schema

    local dispatch_node

    local function handle_sequence(seq_node)
        local seq = {}

        local count = mooncake_0.node_sequence_item_count(seq_node)
        if count == -1 then
            error('Unable to get sequence count')
        end

        for item_idx = 0, count - 1 do
            local node = mooncake_0.node_sequence_get_by_index(seq_node, item_idx)
            table.insert(seq, dispatch_node(node))
        end

        return seq
    end

    local function handle_mapping(mapping_node)
        local map = {}

        local count = mooncake_0.node_mapping_item_count(mapping_node)
        if count == -1 then
            error('Unable to get mapping count')
        end

        for item_idx = 0, count - 1 do
            local node_pair = mooncake_0.node_mapping_get_by_index(mapping_node, item_idx)

            local key_node, value_node = mooncake_0.node_pair_key(node_pair), mooncake_0.node_pair_value(node_pair)
            local key, value = dispatch_node(key_node), dispatch_node(value_node)

            map[key] = value
        end

        return map
    end

    local function handle_scalar(scalar_node)
        local node = scalar_node
        if mooncake_0.node_is_alias(scalar_node) then
            node = mooncake_0.node_resolve_alias(scalar_node)
        end

        return schema(mooncake_0.node_get_scalar(scalar_node))
    end

    dispatch_node = function (node)
        if mooncake_0.node_is_scalar(node) then
            return handle_scalar(node)
        elseif mooncake_0.node_is_sequence(node) then
            return handle_sequence(node)
        elseif mooncake_0.node_is_mapping(node) then
            return handle_mapping(node)
        else
            error('Unknown node type')
        end
    end

    local parse_cfg_flags = mooncake_0.encode_parse_cfg_flags{
        default_version = '1.2'
    }
    local parse_cfg = mooncake_0.encode_parse_cfg{ flags = parse_cfg_flags }

    local doc = mooncake_0.document_build_from_file(parse_cfg, path)
    local root = mooncake_0.document_root(doc)

    -- NOTE: do not use `return dispatch_node(root)` which is a 'proper tail call'
    -- and can leads to var `document` being gc-ed before expected.
    local ret = dispatch_node(root)

    -- release libfyaml internal data structure
    mooncake_0.document_destroy(doc)
    return ret
end

function M:write(node, path)
    local document = self:write_str(node)

    local file = io.open(path, 'w')
    file:write(document)
    file:close()
end

function M:write_str(node)
    local parse_cfg_flags = mooncake_0.encode_parse_cfg_flags{
        default_version = '1.2'
    }
    local parse_cfg = mooncake_0.encode_parse_cfg{ flags = parse_cfg_flags }

    local doc = mooncake_0.document_create(parse_cfg)

    local dispatch_node

    local function handle_table(node)
        if #node > 0 then
            -- YAML sequence for Lua arrays
            local sequence = mooncake_0.node_create_sequence(doc)
            for _, item in ipairs(node) do
                if mooncake_0.node_sequence_append(sequence, dispatch_node(item)) ~= 0 then
                    error('Unable to append item "' .. tostring(item) .. '"')
                end
            end

            return sequence
        elseif next(node) ~= nil then
            -- YAML mapping for non-array Lua tables
            local mapping = mooncake_0.node_create_mapping(doc)
            for key, value in pairs(node) do
                if mooncake_0.node_mapping_append(mapping, dispatch_node(key), dispatch_node(value)) ~= 0 then
                    error('Unable to append key = "' .. tostring(key) .. '", value = "' .. tostring(value) .. '"')
                end
            end

            return mapping
        else
            -- Empty YAML sequence for empty Lua tables
            return mooncake_0.node_create_sequence(doc)
        end
    end

    local function handle_scalar(node)
        return mooncake_0.node_create_scalar_copy(doc, node, #node)
    end

    dispatch_node = function (node)
        if type(node) == 'table' then
            return handle_table(node)
        elseif node == nil then
            return handle_scalar('null')
        -- Special handling for empty strings - write them as '',
        -- since otherwise they're treated as nil on load.
        elseif (type(node) == 'string') and (#node == 0) then
            return handle_scalar(string.format("'%s'", node))
        else
            return handle_scalar(tostring(node))
        end
    end

    local root = dispatch_node(node)

    if mooncake_0.document_set_root(doc, root) ~= 0 then
        error('Unable to set document root')
    end

    local emitter_cfg_flags = mooncake_0.encode_emitter_cfg_flags{
        sort_keys = true,
        indent = 4,
        width = 255,
        mode = 'block'
    }

    local document = mooncake_0.emit_document_to_string(doc, emitter_cfg_flags)

    -- This will also free all created nodes
    mooncake_0.document_destroy(doc)

    return document
end


return setmetatable(M, {
    __gc = function (self)
        if self.has_registry_been_registered then
            mooncake_0.unregister_callback_registry()
        end
    end
})
