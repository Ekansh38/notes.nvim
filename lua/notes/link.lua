local M = {}

-- Scans the line for all [[...]] spans and returns the title under the cursor.
-- Handles: [[Note Title]], [[Note Title|alias]], cursor anywhere inside brackets.
function M.get_link_at_cursor()
    local line = vim.api.nvim_get_current_line()
    local col  = vim.api.nvim_win_get_cursor(0)[2] + 1 -- convert to 1-indexed

    local pos = 1
    while pos <= #line do
        -- find next [[ opening
        local open_s, open_e = line:find("%[%[", pos)
        if not open_s then break end

        -- find matching ]] closing (search after the [[)
        local close_s, close_e = line:find("%]%]", open_e + 1)
        if not close_s then break end

        -- check if cursor falls anywhere inside this link span (including brackets)
        if col >= open_s and col <= close_e then
            local inner = line:sub(open_e + 1, close_s - 1)
            -- strip alias: [[Title|Alias]] → "Title"
            local title = inner:match("^([^|]+)") or inner
            return vim.trim(title)
        end

        pos = close_e + 1
    end

    return nil
end

function M.follow()
    local title = M.get_link_at_cursor()
    if not title then
        -- not on a wikilink — fall back to built-in gf (normal! ignores remaps)
        vim.cmd("normal! gf")
        return
    end

    local util = require("notes.util")
    local path = util.find_note(title)

    if path then
        vim.cmd("edit " .. vim.fn.fnameescape(path))
    else
        -- Note doesn't exist: create it in vault root, open template picker
        local cfg       = require("notes").config
        local safe      = title:gsub("[/\\]", "-") -- no path separators in title
        local new_path  = cfg.vault_path .. "/" .. safe .. ".md"
        require("notes.note").create({ title = safe, path = new_path })
    end
end

return M
