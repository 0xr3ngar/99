local geo = require("99.geo")
local Point = geo.Point
local Request = require("99.request")
local Mark = require("99.ops.marks")
local editor = require("99.editor")
local RequestStatus = require("99.ops.request_status")
local Window = require("99.window")
local make_clean_up = require("99.ops.clean-up")
local Agents = require("99.extensions.agents")
local ExplanationCache = require("99.ops.explanation-cache")

--- @param context _99.RequestContext
--- @param opts? _99.ops.Opts
local function explain_function(context, opts)
  opts = opts or {}
  local logger = context.logger:set_area("explain_function")
  local ts = editor.treesitter
  local buffer = vim.api.nvim_get_current_buf()
  local cursor = Point:from_cursor()
  local func = ts.containing_function(context, cursor)

  if not func then
    logger:fatal("explain_function: unable to find any containing function")
    return
  end

  context.range = func.function_range
  context.text_response = true

  logger:debug("explain_function", "opts", opts)
  local virt_line_count = context._99.ai_stdout_rows
  if virt_line_count >= 0 then
    context.marks.function_location = Mark.mark_func_body(buffer, func)
  end

  local func_row = func.function_range.start.row - 1

  local request = Request.new(context)
  local full_prompt = context._99.prompts.prompts.explain_function()
  local additional_prompt = opts.additional_prompt
  if additional_prompt then
    full_prompt =
      context._99.prompts.prompts.prompt(additional_prompt, full_prompt)

    local rules = Agents.find_rules(context._99.rules, additional_prompt)
    logger:debug("found rules", "rules", rules)
    context:add_agent_rules(rules)
  end

  local additional_rules = opts.additional_rules
  if additional_rules then
    logger:debug("additional_rules", "additional_rules", additional_rules)
    context:add_agent_rules(additional_rules)
  end

  request:add_prompt_content(full_prompt)

  local request_status = RequestStatus.new(
    250,
    context._99.ai_stdout_rows,
    "Explaining",
    context.marks.function_location
  )
  request_status:start()

  local clean_up = make_clean_up(context, function()
    context:clear_marks()
    request:cancel()
    request_status:stop()
  end)

  request:start({
    on_stdout = function(line)
      request_status:push(line)
    end,
    on_complete = function(status, response)
      logger:info("on_complete", "status", status, "response", response)
      vim.schedule(clean_up)

      if status == "failed" then
        if context._99.display_errors then
          Window.display_error(
            "Error encountered while processing explain_function\n"
              .. (response or "No Error text provided.  Check logs")
          )
        end
        logger:error(
          "unable to explain function, enable and check logger for more details"
        )
      elseif status == "cancelled" then
        logger:debug("explain_function was cancelled")
      elseif status == "success" then
        vim.schedule(function()
          ExplanationCache.store(buffer, func_row, response)
        end)
      end
    end,
    on_stderr = function(line)
      logger:debug("explain_function#on_stderr", "line", line)
    end,
  })
end

return explain_function
