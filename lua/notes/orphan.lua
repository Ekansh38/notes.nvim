-- Telescope picker: list notes with no inbound [[wikilinks]] (orphans).

local M = {}

function M.show()
    local pickers      = require("telescope.pickers")
    local finders      = require("telescope.finders")
    local conf         = require("telescope.config").values
    local actions      = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local orphans = require("notes.util").orphan_notes()

    if #orphans == 0 then
        vim.notify("notes: no orphan notes — everything is linked!", vim.log.levels.INFO)
        return
    end

    pickers.new({}, {
        prompt_title = "Orphan Notes — " .. #orphans .. " unlinked",
        finder = finders.new_table({
            results = orphans,
            entry_maker = function(path)
                local title = vim.fn.fnamemodify(path, ":t:r")
                return {
                    value   = path,
                    display = title,
                    ordinal = title,
                    path    = path,
                }
            end,
        }),
        sorter    = conf.generic_sorter({}),
        previewer = conf.file_previewer({}),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local sel = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                vim.cmd("edit " .. vim.fn.fnameescape(sel.value))
            end)
            return true
        end,
    }):find()
end

return M
