-- Extract selected lines into a new note and replace the selection with [[wikilink]].
-- Visual mode → <leader>oe → prompt for title → creates note → replaces selection.

local M = {}

function M.extract()
    -- Marks are set before the keymap fires (vim exits visual first)
    local s_row = vim.fn.getpos("'<")[2]
    local e_row = vim.fn.getpos("'>")[2]

    if s_row == 0 or e_row == 0 then
        vim.notify("notes: no selection", vim.log.levels.WARN)
        return
    end

    -- Grab the selected lines (full lines — cleanest for note extraction)
    local lines = vim.api.nvim_buf_get_lines(0, s_row - 1, e_row, false)
    if #lines == 0 then
        vim.notify("notes: empty selection", vim.log.levels.WARN)
        return
    end

    local content = table.concat(lines, "\n")

    vim.ui.input({ prompt = "Extract to note: " }, function(input)
        if not input or vim.trim(input) == "" then return end

        local title = vim.trim(input):gsub("[/\\]", "-")
        local cfg   = require("notes").config
        local path  = cfg.vault_path .. "/" .. title .. ".md"

        if vim.fn.filereadable(path) == 1 then
            vim.notify('notes: "' .. title .. '" already exists', vim.log.levels.WARN)
            return
        end

        -- Write extracted content to the new note file
        vim.fn.writefile(vim.split(content, "\n", { plain = true }), path)

        -- Replace the selection with a [[wikilink]]
        vim.api.nvim_buf_set_lines(0, s_row - 1, e_row, false, { "[[" .. title .. "]]" })

        -- Invalidate index so the new note shows up in completions immediately
        require("notes.util").invalidate()

        vim.notify('notes: extracted → "' .. title .. '"', vim.log.levels.INFO)
    end)
end

return M
