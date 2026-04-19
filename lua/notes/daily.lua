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

return M
