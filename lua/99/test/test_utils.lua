local M = {}

function M.next_frame()
    local next = false
    vim.schedule(function()
        next = true
    end)

    vim.wait(1000, function() return next end)
end


M.created_files = {}

--- @class _99.test.ProviderRequest
--- @field query string
--- @field context _99.Context
--- @field observer _99.ProviderObserver?

--- @class _99.test.Provider : _99.Provider
--- @field request _99.test.ProviderRequest?
local TestProvider = {}
TestProvider.__index = TestProvider

function TestProvider.new()
    return setmetatable({}, TestProvider)
end

--- @param query string
---@param context _99.Context
---@param observer _99.ProviderObserver?
function TestProvider:make_request(query, context, observer)
    self.request = {
        query = query,
        context = context,
        observer = observer,
    }
end

--- @param success boolean
--- @param result string
function TestProvider:resolve(success, result)
    assert(self.request, "you cannot call resolve until make_request is called")
    local obs = self.request.observer
    if obs then
        print("complete callback", vim.inspect(obs))
        obs.on_complete(success, result)
    end
    self.request = nil
end

--- @param line string
function TestProvider:stdout(line)
    assert(self.request, "you cannot call stdout until make_request is called")
    local obs = self.request.observer
    if obs then
        obs.on_stdout(line)
    end
end

--- @param line string
function TestProvider:stderr(line)
    assert(self.request, "you cannot call stderr until make_request is called")
    local obs = self.request.observer
    if obs then
        obs.on_stderr(line)
    end
end

M.TestProvider = TestProvider

function M.clean_files()
    for _, bufnr in ipairs(M.created_files) do
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    M.created_files = {}
end

---@param contents string[]
---@param file_type string?
---@param row number?
---@param col number?
function M.create_file(contents, file_type, row, col)
    assert(type(contents) == "table", "contents must be a table of strings")
    file_type = file_type or "lua"
    local bufnr = vim.api.nvim_create_buf(false, false)

    vim.api.nvim_set_current_buf(bufnr)
    vim.bo[bufnr].ft = file_type
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    print("row", row or 1, "col", col or 0)
    vim.api.nvim_win_set_cursor(0, { row or 1, col or 0 })

    table.insert(M.created_files, bufnr)
    return bufnr
end

return M
