local geo = require("99.geo")
local Range = geo.Range
local Point = geo.Point
local Logger = require("99.logger.logger")
local Request = require("99.request")
local marks = require("99.ops.marks")
local Context = require("99.ops.context")
local editor = require("99.editor")
local Languages = require("99.language")

--- @param res string
--- @param location _99.Location
local function update_file_with_changes(res, location)
    assert(
        location.marks.function_location,
        "function_location mark was not set, unrecoverable error"
    )
    local mark = location.marks.function_location
    local buffer = location.buffer

    local mark_pos = vim.api.nvim_buf_get_mark(buffer, mark)
    local mark_point = Point:new(mark_pos[1], mark_pos[2] + 1)

    local ts = editor.treesitter
    local scopes = ts.function_scopes(mark_point, buffer)

    if not scopes or not scopes:has_scope() then
        Logger:error(
            "update_file_with_changes: unable to find function at mark location"
        )
        error(
            "update_file_with_changes: funable to find function at mark location"
        )
        return
    end

    local range = scopes.range[#scopes.range]

    local function_start_row, _ = range.start:to_vim()
    local function_end_row, _ = range.end_:to_vim()

    local lines = vim.split(res, "\n")
    vim.api.nvim_buf_set_lines(
        buffer,
        function_start_row,
        function_end_row + 1,
        false,
        lines
    )
end

--- @param _99 _99.State
--- @param location _99.Location
---@param thoughts string[]
local function update_with_cot(_99, location, thoughts)
    local lines = _99.ai_stdout_rows
    --- use nvim_buf_set_extmark({buffer}, {ns_id}, {line}, {col}, {opts})
    --- only show the last few thoughts lines
    --- i want to display virtual text of the latest thoughts
end

--- @param _99 _99.State
local function fill_in_function(_99)
    local ts = editor.treesitter
    local cursor = Point:from_cursor()
    local scopes = ts.function_scopes(cursor)
    local scope = scopes:get_inner_scope()
    local range = scopes:get_inner_range()

    if not range or not scope then
        Logger:error("fill_in_function: unable to find any containing function")
        error("you cannot call fill_in_function not in a function")
    end

    local location = editor.Location.from_ts_node(scope, range)
    local ai_input_row = Languages.add_function_spacing(_99, location)
    if ai_input_row == -1 then
        Logger:warn("fill_in_function: add_function_spacing returned -1")
    else
        local buffer = location.buffer
        local mark = marks(
            buffer,
            Range:new(
                buffer,
                Point:new(ai_input_row, 1),
                Point:new(ai_input_row, 1)
            )
        )
    end

    -- location.marks.virtual_text_start = marks(buffer,
    local context = Context.new(_99):finalize(_99, location)
    local request = Request.new({
        provider = _99.provider_override,
        model = _99.model,
        context = context,
    })

    context:add_to_request(request)
    location.marks.function_location = marks(location.buffer, range)
    request:add_prompt_content(_99.prompts.prompts.fill_in_function)

    request:start({
        on_stdout = function(line) end,
        on_complete = function(ok, response)
            if not ok then
                Logger:fatal(
                    "unable to fill in function, enable and check logger for more details"
                )
            end
            update_file_with_changes(response, location)
        end,
        on_stderr = function(line)
        end,
    })
end

return fill_in_function
