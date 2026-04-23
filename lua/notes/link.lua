local M = {}

-- ── markdown link detection ───────────────────────────────────────────────────
-- Returns the URL if cursor is inside a [text](url) span, else nil.

local function get_md_url_at_cursor()
    local line = vim.api.nvim_get_current_line()
    local col  = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-indexed

    local pos = 1
    while pos <= #line do
        local bracket_s = line:find("%[", pos)
        if not bracket_s then break end

        -- Skip [[ (wikilinks) and ![ (images)
        local prev = bracket_s > 1 and line:sub(bracket_s - 1, bracket_s - 1) or ""
        if prev == "[" or prev == "!" then
            pos = bracket_s + 1
            goto next
        end

        local bracket_e = line:find("%]%(", bracket_s + 1)
        if not bracket_e then break end

        -- Find matching ) tracking paren depth
        local paren_s = bracket_e + 1
        local depth   = 1
        local paren_e = nil
        for i = paren_s + 1, #line do
            local c = line:sub(i, i)
            if     c == "(" then depth = depth + 1
            elseif c == ")" then
                depth = depth - 1
                if depth == 0 then paren_e = i; break end
            end
        end
        if not paren_e then break end

        if col >= bracket_s and col <= paren_e then
            return line:sub(paren_s + 1, paren_e - 1)
        end

        pos = paren_e + 1
        ::next::
    end
    return nil
end

-- ── wikilink detection ────────────────────────────────────────────────────────
-- Scans the line for all [[...]] spans and returns the raw inner text under
-- the cursor (including optional #heading). Handles [[Title]], [[Title|Alias]].

function M.get_link_at_cursor()
    local line = vim.api.nvim_get_current_line()
    local col  = vim.api.nvim_win_get_cursor(0)[2] + 1

    local pos = 1
    while pos <= #line do
        local open_s, open_e = line:find("%[%[", pos)
        if not open_s then break end

        local close_s, close_e = line:find("%]%]", open_e + 1)
        if not close_s then break end

        if col >= open_s and col <= close_e then
            local inner = line:sub(open_e + 1, close_s - 1)
            local title = inner:match("^([^|]+)") or inner
            return vim.trim(title)
        end

        pos = close_e + 1
    end

    return nil
end

-- ── follow ────────────────────────────────────────────────────────────────────
-- Priority: markdown [text](url) → wikilink [[Title]] → default gf

function M.follow()
    -- 1. Markdown link → open URL in browser
    local url = get_md_url_at_cursor()
    if url and url:match("^https?://") then
        vim.fn.jobstart({ "open", url }, { detach = true })
        vim.notify("opening: " .. url, vim.log.levels.INFO)
        return
    end

    -- 2. Wikilink → open or create note
    local raw = M.get_link_at_cursor()
    if not raw then
        pcall(vim.cmd, "normal! gf")
        return
    end

    local note_part, heading = raw:match("^([^#]+)#(.+)$")
    if not note_part then note_part = raw end
    note_part = vim.trim(note_part)
    heading   = heading and vim.trim(heading) or nil

    local util = require("notes.util")
    local path = util.find_note(note_part)

    if path then
        vim.cmd("edit " .. vim.fn.fnameescape(path))

        if heading then
            local lower_h = heading:lower()
            local lines   = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            for lnum, line in ipairs(lines) do
                local h = line:match("^#+%s+(.+)$")
                if h and h:lower() == lower_h then
                    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
                    vim.cmd("normal! zz")
                    break
                end
            end
        end
    else
        local cfg      = require("notes").config
        local safe     = note_part:gsub("[/\\]", "-")
        local new_path = cfg.vault_path .. "/" .. safe .. ".md"
        require("notes.note").create({ title = safe, path = new_path })
    end
end

return M
