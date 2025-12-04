local Logger = require("99.logger.logger")
local Level = require("99.logger.level")
local ops = require("99.ops")
local Languages = require("99.language")

--- @class _99.Options
--- @field logger _99.Logger.Options?
--- @field model string?
--- @field md_files string[]?
--- @field provider _99.Provider?

--- unanswered question -- will i need to queue messages one at a time or
--- just send them all...  So to prepare ill be sending around this state object
--- @class _99.State
--- @field model string
--- @field md_files string[]
--- @field prompts _99.Prompts
--- @field ai_stdout_rows number
--- @field languages string[]
--- @field provider_override _99.Provider?

--- @return _99.State
local function create_99_state()
    return {
        model = "anthropic/claude-sonnet-4-5",
        md_files = {},
        prompts = require("99.prompt_settings"),
        ai_stdout_rows = 3,
        languages = { "lua" },
    }
end

local _99_state = create_99_state()

--- @class _99
local _99 = {
    DEBUG = Level.DEBUG,
    INFO = Level.INFO,
    WARN = Level.WARN,
    ERROR = Level.ERROR,
    FATAL = Level.FATAL,
}

function _99.implement_fn()
    local impl = ops.implement_fn(_99_state)
    impl:start()
end

function _99.fill_in_function()
    ops.fill_in_function(_99_state)
end

--- @param opts _99.Options?
function _99.setup(opts)
    opts = opts or {}
    _99_state = create_99_state()
    _99_state.provider_override = opts.provider

    Logger:configure(opts.logger)

    if opts.model then
        assert(type(opts.model) == "string", "opts.model is not a string")
        _99_state.model = opts.model
    end

    if opts.md_files then
        assert(type(opts.md_files) == "table", "opts.md_files is not a table")
        for _, md in ipairs(opts.md_files) do
            _99.add_md_file(md)
        end
    end

    Languages.initialize(_99_state)
end

--- @param md string
--- @return _99
function _99.add_md_file(md)
    table.insert(_99_state.md_files, md)
    return _99
end

--- @param md string
--- @return _99
function _99.rm_md_file(md)
    for i, name in ipairs(_99_state.md_files) do
        if name == md then
            table.remove(_99_state.md_files, i)
            break
        end
    end
    return _99
end

--- @param model string
--- @return _99
function _99.set_model(model)
    _99_state.model = model
    return _99
end

return _99
