-- Press K on a [[wikilink]] to peek at the linked note in a floating window.
-- Auto-closes on any cursor movement.

local M = {}

function M.show()
    local raw_title = require("notes.link").get_link_at_cursor()
    if not raw_title then
        vim.notify("notes: no wikilink under cursor", vim.log.levels.INFO)
        return
    end

    -- Split [[Note#Heading]] into parts
    local note_title = vim.trim(raw_title:match("^([^#]+)") or raw_title)
    local heading    = raw_title:match("^[^#]+#(.+)$")
    if heading then heading = vim.trim(heading) end

    local path = require("notes.util").find_note(note_title)
    if not path then
        vim.notify("notes: note not found: " .. note_title, vim.log.levels.INFO)
        return
    end

    local all_lines = vim.fn.readfile(path)

    -- Find where to start: heading section if specified, else after frontmatter
    local body_start = 1
    if heading then
        local lower_h = heading:lower()
        for i, line in ipairs(all_lines) do
            local h = line:match("^#+%s+(.+)$")
            if h and h:lower() == lower_h then
                body_start = i
                break
            end
        end
    elseif all_lines[1] == "---" then
        for i = 2, #all_lines do
            if all_lines[i] == "---" or all_lines[i] == "..." then
                body_start = i + 1
                break
            end
        end
    end

    -- Collect up to 25 lines from start point
    local preview = {}
    local found   = false
    for i = body_start, #all_lines do
        if not found and all_lines[i]:match("^%s*$") then goto skip end
        found = true
        preview[#preview + 1] = all_lines[i]
        if #preview >= 25 then break end
        ::skip::
    end

    if #preview == 0 then
        preview = { "(empty note)" }
    elseif #preview >= 25 then
        preview[#preview + 1] = "…"
    end

    -- Scratch buffer with markdown filetype so treesitter highlights it
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, preview)
    vim.bo[buf].filetype   = "markdown"
    vim.bo[buf].modifiable = false

    local width  = math.min(72, vim.o.columns - 6)
    local height = math.min(#preview, 20)

    local win = vim.api.nvim_open_win(buf, false, {
        relative  = "cursor",
        row       = 1,
        col       = 0,
        width     = width,
        height    = height,
        style     = "minimal",
        border    = "rounded",
        title     = " " .. note_title .. (heading and (" # " .. heading) or "") .. " ",
        title_pos = "center",
    })

    -- Close when cursor moves or we leave the buffer
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave", "InsertEnter" }, {
        buffer   = vim.api.nvim_get_current_buf(),
        once     = true,
        callback = function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end,
    })
end

return M
