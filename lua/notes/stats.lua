-- Vault stats floating window — <leader>os
-- Shows: note count, tag stats, orphan count, most linked note, last edited note.

local M = {}

function M.show()
    local util = require("notes.util")

    local all_tags  = util.all_tags()
    local orphans   = util.orphan_notes()
    local notes_raw = util.all_notes_for_completion()

    local note_count = 0
    for _, n in ipairs(notes_raw) do
        if n.exists then note_count = note_count + 1 end
    end

    local tag_count = #all_tags
    local tag_uses  = 0
    for _, t in ipairs(all_tags) do tag_uses = tag_uses + #t.paths end

    local most  = util.most_linked()
    local last  = util.last_modified()

    local W = 46
    local function pad(label, value)
        local gap = W - 4 - #label - #value
        return "  " .. label .. string.rep(" ", math.max(1, gap)) .. value
    end

    local lines = {
        "",
        pad("Notes",       tostring(note_count)),
        pad("Tags",        string.format("%d unique, %d uses", tag_count, tag_uses)),
        pad("Orphans",     tostring(#orphans)),
        "",
        pad("Most linked", most and (most.title .. "  ×" .. most.count) or "—"),
        pad("Last edited", last and last.title or "—"),
        last and ("  " .. last.time) or "",
        "",
    }

    local height = #lines
    local row    = math.floor((vim.o.lines   - height) / 2)
    local col    = math.floor((vim.o.columns - W)      / 2)

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].bufhidden  = "wipe"

    local winnr = vim.api.nvim_open_win(bufnr, true, {
        relative  = "editor",
        row       = row,
        col       = col,
        width     = W,
        height    = height,
        border    = "rounded",
        title     = " vault stats ",
        title_pos = "center",
        style     = "minimal",
    })

    local function close()
        if vim.api.nvim_win_is_valid(winnr) then
            vim.api.nvim_win_close(winnr, true)
        end
    end

    vim.keymap.set("n", "q",     close, { buffer = bufnr, nowait = true })
    vim.keymap.set("n", "<Esc>", close, { buffer = bufnr, nowait = true })
    vim.keymap.set("n", "<CR>",  close, { buffer = bufnr, nowait = true })

    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
        buffer   = bufnr,
        once     = true,
        callback = close,
    })
end

return M
