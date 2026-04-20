-- Telescope picker: list all tags → pick one → list notes with that tag.

local M = {}

function M.search()
    local pickers      = require("telescope.pickers")
    local finders      = require("telescope.finders")
    local conf         = require("telescope.config").values
    local actions      = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local tags = require("notes.util").all_tags()

    if #tags == 0 then
        vim.notify("notes: no tags found in vault", vim.log.levels.INFO)
        return
    end

    -- First picker: all tags
    pickers.new({}, {
        prompt_title = "Tags",
        finder = finders.new_table({
            results = tags,
            entry_maker = function(entry)
                local count = tostring(#entry.paths)
                return {
                    value   = entry,
                    display = entry.tag .. "  (" .. count .. ")",
                    ordinal = entry.tag,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                local entry = selection.value

                -- Single match: open directly
                if #entry.paths == 1 then
                    vim.cmd("edit " .. vim.fn.fnameescape(entry.paths[1]))
                    return
                end

                -- Multiple matches: second picker
                pickers.new({}, {
                    prompt_title = "Notes tagged #" .. entry.tag,
                    finder = finders.new_table({
                        results = entry.paths,
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
                    attach_mappings = function(pb2, _)
                        actions.select_default:replace(function()
                            local sel = action_state.get_selected_entry()
                            actions.close(pb2)
                            vim.cmd("edit " .. vim.fn.fnameescape(sel.value))
                        end)
                        return true
                    end,
                }):find()
            end)
            return true
        end,
    }):find()
end

return M
