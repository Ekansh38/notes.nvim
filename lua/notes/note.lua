local M = {}

local function pick_template_and_create(title, path)
    local cfg          = require("notes").config
    local template_dir = cfg.vault_path .. "/" .. cfg.templates_dir
    local tmpl_files   = vim.fn.glob(template_dir .. "/*.md", false, true)

    -- No templates found → create blank note
    if #tmpl_files == 0 then
        vim.fn.writefile({}, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf    = require("telescope.config").values
    local actions = require("telescope.actions")
    local state   = require("telescope.actions.state")

    pickers.new({}, {
        prompt_title = 'Template → "' .. title .. '"',
        finder = finders.new_table({
            results = tmpl_files,
            entry_maker = function(tmpl_path)
                local name = vim.fn.fnamemodify(tmpl_path, ":t:r")
                return { value = tmpl_path, display = name, ordinal = name }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local sel = state.get_selected_entry()
                actions.close(prompt_bufnr)
                if not sel then return end -- picker cancelled, abort

                local content, err = require("notes.template").load_and_apply(sel.value, title)
                if err then
                    vim.notify("notes: " .. err, vim.log.levels.ERROR)
                    vim.fn.writefile({}, path)
                else
                    vim.fn.writefile(vim.split(content, "\n"), path)
                end
                vim.cmd("edit " .. vim.fn.fnameescape(path))
            end)
            return true
        end,
    }):find()
end

-- :VaultNew — prompt for title, pick template, create note
function M.new()
    vim.ui.input({ prompt = "Note title: " }, function(input)
        if not input or vim.trim(input) == "" then return end
        local title = vim.trim(input):gsub("[/\\]", "-")
        local cfg   = require("notes").config
        local path  = cfg.vault_path .. "/" .. title .. ".md"

        -- Already exists → just open it
        if vim.fn.filereadable(path) == 1 then
            vim.cmd("edit " .. vim.fn.fnameescape(path))
            return
        end

        pick_template_and_create(title, path)
    end)
end

-- Inject a template into the current buffer at the cursor position.
-- Useful for adding sections to an existing note.
function M.inject()
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname == "" then
        vim.notify("notes: buffer has no file", vim.log.levels.WARN)
        return
    end

    local cfg          = require("notes").config
    local title        = vim.fn.fnamemodify(bufname, ":t:r")
    local template_dir = cfg.vault_path .. "/" .. cfg.templates_dir
    local tmpl_files   = vim.fn.glob(template_dir .. "/*.md", false, true)

    if #tmpl_files == 0 then
        vim.notify("notes: no templates found in " .. template_dir, vim.log.levels.WARN)
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf    = require("telescope.config").values
    local actions = require("telescope.actions")
    local state   = require("telescope.actions.state")

    pickers.new({}, {
        prompt_title = "Inject Template → " .. title,
        finder = finders.new_table({
            results = tmpl_files,
            entry_maker = function(tmpl_path)
                local name = vim.fn.fnamemodify(tmpl_path, ":t:r")
                return { value = tmpl_path, display = name, ordinal = name }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local sel = state.get_selected_entry()
                actions.close(prompt_bufnr)
                if not sel then return end

                local content, err = require("notes.template").load_and_apply(sel.value, title)
                if err then
                    vim.notify("notes: " .. err, vim.log.levels.ERROR)
                    return
                end

                -- Insert after the current cursor row (0-indexed row for nvim API)
                local row = vim.api.nvim_win_get_cursor(0)[1]  -- 1-indexed
                local lines = vim.split(content, "\n", { plain = true })
                vim.api.nvim_buf_set_lines(0, row, row, false, lines)

                -- Move cursor to first inserted line
                vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
            end)
            return true
        end,
    }):find()
end

-- Called by link.follow() when a [[link]] points to a missing note
function M.create(opts)
    local path  = opts.path
    local title = opts.title

    if vim.fn.filereadable(path) == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        return
    end

    pick_template_and_create(title, path)
end

return M
