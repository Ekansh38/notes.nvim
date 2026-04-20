local M = {}

function M.open()
    local cfg       = require("notes").config
    local today     = os.date("%Y-%m-%d")
    local daily_dir = cfg.vault_path .. "/" .. cfg.daily_dir
    local path      = daily_dir .. "/" .. today .. ".md"

    -- Create the daily directory if it somehow doesn't exist
    vim.fn.mkdir(daily_dir, "p")

    -- Already exists → open it
    if vim.fn.filereadable(path) == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        return
    end

    -- Create from the fixed daily template (no picker)
    local tmpl_path = cfg.vault_path .. "/" .. cfg.templates_dir
                      .. "/" .. cfg.daily_template
    local content, err = require("notes.template").load_and_apply(tmpl_path, today)
    if err then
        vim.notify("notes: " .. err .. " — creating empty daily note", vim.log.levels.WARN)
        content = ""
    end

    vim.fn.writefile(vim.split(content, "\n"), path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
end

-- Navigate to the previous or next daily note by date.
-- direction: -1 = previous, 1 = next
function M.navigate(direction)
    local cfg       = require("notes").config
    local daily_dir = cfg.vault_path .. "/" .. cfg.daily_dir
    local files     = vim.fn.glob(daily_dir .. "/????-??-??.md", false, true)

    if #files == 0 then
        vim.notify("notes: no daily notes found", vim.log.levels.INFO)
        return
    end

    table.sort(files)  -- ISO dates sort lexicographically

    -- Current buffer name — find its index in the sorted list
    local current = vim.api.nvim_buf_get_name(0)
    local idx     = nil
    for i, f in ipairs(files) do
        if f == current then idx = i; break end
    end

    local target_idx
    if not idx then
        -- Not currently in a daily note: jump to latest (direction 1) or oldest (-1)
        target_idx = direction == 1 and #files or 1
    else
        target_idx = idx + direction
    end

    if target_idx < 1 or target_idx > #files then
        vim.notify("notes: no " .. (direction == -1 and "earlier" or "later") .. " daily note", vim.log.levels.INFO)
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(files[target_idx]))
end

return M
