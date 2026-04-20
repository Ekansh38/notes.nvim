-- Telescope picker of all headings in the current note.
-- Indented by level. Select → jump to that line and center it.

local M = {}

function M.show()
    local pickers      = require("telescope.pickers")
    local finders      = require("telescope.finders")
    local conf         = require("telescope.config").values
    local actions      = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local lines    = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local headings = {}

    for lnum, line in ipairs(lines) do
        local hashes, title = line:match("^(#+)%s+(.+)$")
        if hashes then
            headings[#headings + 1] = {
                lnum    = lnum,
                level   = #hashes,
                title   = title,
                display = string.rep("  ", #hashes - 1) .. title,
            }
        end
    end

    if #headings == 0 then
        vim.notify("notes: no headings in this note", vim.log.levels.INFO)
        return
    end

    pickers.new({}, {
        prompt_title = "Headings",
        finder = finders.new_table({
            results = headings,
            entry_maker = function(h)
                return {
                    value   = h,
                    display = h.display,
                    ordinal = h.title,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local sel = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                vim.api.nvim_win_set_cursor(0, { sel.value.lnum, 0 })
                vim.cmd("normal! zz")
            end)
            return true
        end,
    }):find()
end

return M
