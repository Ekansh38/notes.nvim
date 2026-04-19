local M = {}

function M.rename()
    local old_path = vim.api.nvim_buf_get_name(0)

    if old_path == "" or not old_path:match("%.md$") then
        vim.notify("vault: not in a markdown note", vim.log.levels.WARN)
        return
    end

    local old_title = vim.fn.fnamemodify(old_path, ":t:r")

    vim.ui.input({ prompt = "Rename to: ", default = old_title }, function(input)
        if not input or vim.trim(input) == "" then return end
        local new_title = vim.trim(input):gsub("[/\\]", "-")

        if new_title == old_title then return end

        local new_path = vim.fn.fnamemodify(old_path, ":h") .. "/" .. new_title .. ".md"

        if vim.fn.filereadable(new_path) == 1 then
            vim.notify("vault: '" .. new_title .. "' already exists", vim.log.levels.ERROR)
            return
        end

        -- 1. Rename the file
        if vim.fn.rename(old_path, new_path) ~= 0 then
            vim.notify("vault: rename failed", vim.log.levels.ERROR)
            return
        end

        -- 2. Relink all .md files in the vault
        local cfg         = require("vault").config
        local files       = vim.fn.glob(cfg.vault_path .. "/**/*.md", false, true)
        local escaped_old = vim.pesc(old_title) -- escape Lua pattern special chars
        local updated     = 0

        for _, fpath in ipairs(files) do
            local lines   = vim.fn.readfile(fpath)
            local changed = false
            for i, line in ipairs(lines) do
                local new_line = line
                    -- [[Old Title]] → [[New Title]]
                    :gsub("%[%[" .. escaped_old .. "%]%]", "[[" .. new_title .. "]]")
                    -- [[Old Title|alias]] → [[New Title|alias]]
                    :gsub("%[%[" .. escaped_old .. "|",    "[[" .. new_title .. "|")
                if new_line ~= line then
                    lines[i] = new_line
                    changed  = true
                end
            end
            if changed then
                vim.fn.writefile(lines, fpath)
                updated = updated + 1
            end
        end

        -- 3. Invalidate the note index
        require("vault.util").invalidate()

        -- 4. Switch current buffer to the renamed file
        vim.cmd("edit " .. vim.fn.fnameescape(new_path))
        local old_buf = vim.fn.bufnr(old_path)
        if old_buf ~= -1 and old_buf ~= vim.api.nvim_get_current_buf() then
            vim.api.nvim_buf_delete(old_buf, { force = true })
        end

        vim.notify(string.format(
            "vault: '%s' → '%s' (relinked %d file%s)",
            old_title, new_title, updated, updated == 1 and "" or "s"
        ))
    end)
end

return M
