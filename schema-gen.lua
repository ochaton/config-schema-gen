#!/usr/bin/env tarantool

local fio = require('fio')
local json = require('json')
local popen = require('popen')
local cluster_config = require('internal.config.cluster_config')

local scalars = {}

scalars.string = {
    jsonschema = {
        type = 'string',
    },
}

scalars.number = {
    jsonschema = {
        type = 'number',
    },
}

scalars['string, number'] = {
    jsonschema = {
        type = {'string', 'number'},
    },
}

scalars['number, string'] = {
    jsonschema = {
        type = {'string', 'number'},
    },
}

scalars.integer = {
    jsonschema = {
        type = 'integer',
    },
}

scalars.boolean = {
    jsonschema = {
        type = 'boolean',
    },
}

scalars.any = {
    jsonschema = {},
}

local function is_scalar(schema)
    return scalars[schema.type] ~= nil
end

local function extract_validate_no_repeat()
    local schema

    for _, p in ipairs{'experimental.config.utils.schema', 'internal.config.utils.schema'} do
        local ok, mod = pcall(require, p)
        if ok then
            schema = mod
            break
        end
    end

    local nups = debug.getinfo(schema.set).nups
    for i = 1, nups do
        local k, v = debug.getupvalue(schema.set, i)
        if k == 'validate_no_repeat' then
            return v
        end
    end
end

local validate_no_repeat = extract_validate_no_repeat()
assert(type(validate_no_repeat) == 'function')

local function set_common_fields(res, schema)
    -- Ignores apply_default_if.
    res.default = schema.default
    res.enum = schema.allowed_values
    return setmetatable(res, {
        __serialize = 'map',
    })
end

local function traverse_impl(schema)
    if is_scalar(schema) then
        local scalar_def = scalars[schema.type]
        assert(scalar_def ~= nil)
        return set_common_fields(table.copy(scalar_def.jsonschema), schema)
    elseif schema.type == 'record' then
        local properties = {}
        for field_name, field_def in pairs(schema.fields) do
            properties[field_name] = traverse_impl(field_def)
        end
        return set_common_fields({
            type = 'object',
            properties = properties,
            additionalProperties = false,
        }, schema)
    elseif schema.type == 'map' then
        assert(schema.key.type == 'string')
        return set_common_fields({
            type = 'object',
            additionalProperties = traverse_impl(schema.value),
        }, schema)
    elseif schema.type == 'array' then
        local res = {
            type = 'array',
            items = traverse_impl(schema.items),
        }
        if schema.validate == validate_no_repeat then
            res.uniqueItems = true
        end
        return set_common_fields(res, schema)
    else
        assert(false)
    end
end

local function traverse(schema_obj)
    local res = traverse_impl(rawget(schema_obj, 'schema'))
    res['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
    return res
end

local parser = require 'argparse'()
    :name "schema-gen"
    :description "Tarantool 3.x json-schema generator"
    :epilog "Take a look https://github.com/tarantool/tarantool"

parser:option "-o" "--output"
    :args "1"
    :target "output_file"

parser:option "-t" "--tarantool"
    :args "1"
    :target "tarantool_bin"

local function main(args)
    -- Get Tarantool version
    local tarantool, orig_version do
        if args.tarantool_bin then
            local yaml = require 'yaml'
            local sock, err = popen.shell(args.tarantool_bin .. ' -e "print(_TARANTOOL)"', 'r')
            if err then
                error(tostring(err))
            end

            tarantool = yaml.decode(sock:read())
            local exit_code = sock.status.exit_code
            if exit_code and exit_code ~= 0 then
                -- io.stderr:write(sock.status)
                io.stderr:write("Failed to get version\n")
                os.exit(exit_code)
                return
            end
            sock:close()
        else
            tarantool = require 'tarantool'.version
        end

        orig_version = tarantool
        tarantool = tarantool
            :gsub("%-", ".")
            :gsub("%.g[0-9a-f]+$", "")
    end

    -- Create output file
    local output do
        if args.output_file then
            local file_name = 'config.schema-'..tarantool..'.json'
            if fio.path.is_dir(args.output_file) then
                file_name = fio.pathjoin(args.output_file, file_name)
            else
                file_name = args.output_file
            end
            output = assert(io.open(file_name, 'w'))
        else
            output = io.stdout
        end
    end

    local text

    if orig_version == require 'tarantool'.version then
        local jsonschema = traverse(cluster_config)
        text = json.encode(jsonschema)
    else
        -- We need to execute another binary Tarantool with this script
        local my_path = fio.abspath(debug.getinfo(1, "S").source:sub(2))
        assert(fio.path.is_file(my_path), "can't find myself")


        -- we run specified tarantool with our path and enforce stdout
        local sock, err = popen.shell(args.tarantool_bin .. ' ' .. my_path, 'r')
        if err then
            error(tostring(err))
        end

        local lines = {}
        repeat
            local line = sock:read()
            table.insert(lines, line)
        until line == ""
        text = table.concat(lines, "")

        local exit_code = sock.status.exit_code
        if exit_code and exit_code ~= 0 then
            io.stderr:write("Failed to get schema\n")
            os.exit(exit_code)
            return
        end
        sock:close()
    end

    output:write(text)
end

main(parser:parse())
os.exit(0)

