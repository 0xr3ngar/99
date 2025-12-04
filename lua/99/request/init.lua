local Logger = require("99.logger.logger")

local _id = 1
--- no, i am not going to use a uuid, in case of collision, call the police
--- @return string
local function get_id()
    local id = _id
    _id = _id + 1
    return tostring(id)
end

--- @param opts _99.Request.Opts
local function validate_opts(opts)
    assert(opts.model, "you must provide a model for hange requests to work")
    assert(opts.context, "you must provide context")
    assert(opts.provider, "you must provide a model provider")
end

--- @alias _99.Request.State "ready" | "calling-model" | "parsing-result" | "updating-file"

--- @class _99.ProviderObserver
--- @field on_stdout fun(line: string): nil
--- @field on_stderr fun(line: string): nil
--- @field on_complete fun(success: boolean, res: string): nil

--- @class _99.Provider
--- @field make_request fun(self: _99.Provider, query: string, context: _99.Context, observer: _99.ProviderObserver)

local DevNullObserver = {
    name = "DevNullObserver",
    on_stdout = function() end,
    on_stderr = function() end,
    on_complete = function() end,
}

local OpenCodeProvider = {}

--- @param query string
---@param context _99.Context
---@param observer _99.ProviderObserver?
function OpenCodeProvider:make_request(query, context, observer)
    observer = observer or DevNullObserver
    local id = get_id()
    Logger:debug("99#make_query", "id", id, "query", query)
    vim.system(
        { "opencode", "run", "-m", "anthropic/claude-sonnet-4-5", query },
        {
            text = true,
            stdout = vim.schedule_wrap(function(err, data)
                Logger:debug("STDOUT#data", "id", id, "data", data)
                if err and err ~= "" then
                    Logger:debug("STDOUT#error", "id", id, "err", err)
                end
                if not err then
                    observer.on_stdout(data)
                end
            end),
            stderr = vim.schedule_wrap(function(err, data)
                Logger:debug("STDERR#data", "id", id, "data", data)
                if err and err ~= "" then
                    Logger:debug("STDERR#error", "id", id, "err", err)
                end
                if not err then
                    observer.on_stderr(data)
                end
            end),
        },
        function(obj)
            if obj.code ~= 0 then
                Logger:fatal(
                    "opencode make_query failed",
                    "id",
                    id,
                    "obj from results",
                    obj
                )
                return
            end
            vim.schedule(function()
                local ok, res = OpenCodeProvider._retrieve_response(context)
                observer.on_complete(ok, res)
            end)
        end
    )
end

--- @param context _99.Context
function OpenCodeProvider._retrieve_response(context)
    local tmp = context.tmp_file
    local success, result = pcall(function()
        return vim.fn.readfile(tmp)
    end)

    if not success then
        Logger:error(
            "retrieve_results: failed to read file",
            "tmp_name",
            tmp,
            "error",
            result
        )
        return false, ""
    end

    return true, table.concat(result, "\n")
end

--- @class _99.Request.Opts
--- @field model string
--- @field context _99.Context
--- @field provider _99.Provider?

--- @class _99.Request.Config
--- @field model string
--- @field context _99.Context
--- @field provider _99.Provider

--- @class _99.Request
--- @field config _99.Request.Config
--- @field state _99.Request.State
--- @field _content string[]
local Request = {}
Request.__index = Request

--- @param opts _99.Request.Opts
function Request.new(opts)
    validate_opts(opts)

    opts.provider = opts.provider or OpenCodeProvider

    local config = opts --[[ @as _99.Request.Config ]]

    return setmetatable({
        config = config,
        state = "ready",
        _content = {},
    }, Request)
end

--- @param content string
--- @return self
function Request:add_prompt_content(content)
    table.insert(self._content, content)
    return self
end

--- @param observer _99.ProviderObserver?
function Request:start(observer)
    local query = table.concat(self._content, "\n")
    observer = observer or DevNullObserver
    self.config.provider:make_request(query, self.config.context, observer)
end

return Request
