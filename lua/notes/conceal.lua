-- Extmark-based wikilink concealment. Works alongside treesitter (unlike syn rules).
--
-- [[Title]]        → shows "Title"  (underlined, [[ and ]] hidden)
-- [[Title|Alias]]  → shows "Alias"  (underlined, [[Title| and ]] hidden)
--
-- conceallevel must be >= 1 for this to take effect (set in options.lua).

local M = {}
local ns = vim.api.nvim_create_namespace("notes_conceal")

local function apply(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    for lnum, line in ipairs(lines) do
        local row = lnum - 1 -- nvim extmarks are 0-indexed rows
        local pos  = 1

        while pos <= #line do
            local open_s, open_e = line:find("%[%[", pos)
            if not open_s then break end

            local close_s, close_e = line:find("%]%]", open_e + 1)
            if not close_s then break end

            local inner = line:sub(open_e + 1, close_s - 1)
            local pipe  = inner:find("|", 1, true) -- position within inner (1-indexed)

            -- All cols below are 0-indexed; end_col is exclusive (nvim convention).

            -- conceal  [[
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, open_s - 1, {
                end_col = open_e,
                conceal = "",
            })

            if pipe then
                -- conceal "Title|"  (everything from after [[ up to and including |)
                vim.api.nvim_buf_set_extmark(bufnr, ns, row, open_e, {
                    end_col = open_e + pipe, -- pipe is 1-indexed in inner, so open_e+pipe is exclusive end in line
                    conceal = "",
                })
                -- highlight the alias text
                vim.api.nvim_buf_set_extmark(bufnr, ns, row, open_e + pipe, {
                    end_col  = close_s - 1,
                    hl_group = "NotesWikiLink",
                })
            else
                -- highlight the title text
                vim.api.nvim_buf_set_extmark(bufnr, ns, row, open_e, {
                    end_col  = close_s - 1,
                    hl_group = "NotesWikiLink",
                })
            end

            -- conceal  ]]
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, close_s - 1, {
                end_col = close_e,
                conceal = "",
            })

            pos = close_e + 1
        end
    end
end

function M.attach(bufnr)
    -- Link to markdown's treesitter link highlight; falls back gracefully.
    vim.api.nvim_set_hl(0, "NotesWikiLink", { link = "@markup.link" })

    apply(bufnr)

    -- Keep extmarks current as the user types
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer   = bufnr,
        callback = function() apply(bufnr) end,
    })
end

return M
