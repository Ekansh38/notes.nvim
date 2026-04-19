-- Extmark-based concealment for vault markdown. Works alongside treesitter.
--
-- Handles:
--   [[Title]]        → "Title"       (wikilink, underlined)
--   [[Title|Alias]]  → "Alias"       (aliased wikilink, underlined)
--   `code`           → code          (inline code, slight bg highlight)
--   ==text==         → text          (highlight mark, yellow)
--
-- conceallevel >= 1 required (set globally in options.lua).

local M = {}
local ns = vim.api.nvim_create_namespace("notes_conceal")

-- ── highlight groups ──────────────────────────────────────────────────────────

local function setup_highlights()
    -- default = true means the colorscheme wins if it defines the group;
    -- these only kick in when the theme leaves them undefined.

    -- Wikilinks → whatever the theme uses for links, fall back to Underlined
    vim.api.nvim_set_hl(0, "@markup.link",    { link = "Underlined", default = true })
    vim.api.nvim_set_hl(0, "NotesWikiLink",   { link = "@markup.link", default = true })

    -- ==highlight== → fall back to a Search-style highlight (theme-neutral)
    vim.api.nvim_set_hl(0, "NotesHighlight",  { link = "Search", default = true })

    -- Inline `code` → subtle bg, fine because it's inline (only covers the word)
    vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { link = "CursorLine", default = true })
    vim.api.nvim_set_hl(0, "NotesInlineCode",             { link = "@markup.raw.markdown_inline", default = true })

    -- Fenced code block background. Terminal can't extend it to full line width
    -- so it only covers the text, not the whole line (unlike Obsidian).
    -- Comment these two lines out if you prefer no background.
    vim.api.nvim_set_hl(0, "@markup.raw.block",          { link = "CursorLine", default = true })
    vim.api.nvim_set_hl(0, "@markup.raw.block.markdown", { link = "CursorLine", default = true })
    -- Fence ``` lines and language tag → dimmed like comments
    vim.api.nvim_set_hl(0, "@markup.raw.delimiter.markdown", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "@label.markdown",                { link = "Comment", default = true })
end

-- ── per-pattern helpers (all positions: Lua 1-indexed in, 0-indexed extmarks) ─

local function conceal(bufnr, row, col_1, end_col_1)
    -- col_1, end_col_1: 1-indexed inclusive → 0-indexed exclusive
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, col_1 - 1, {
        end_col = end_col_1,
        conceal = "",
    })
end

local function highlight(bufnr, row, col_1, end_col_1, hl)
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, col_1 - 1, {
        end_col  = end_col_1,
        hl_group = hl,
    })
end

-- ── wikilinks ─────────────────────────────────────────────────────────────────

local function apply_wikilinks(bufnr, row, line)
    local pos = 1
    while pos <= #line do
        local open_s, open_e = line:find("%[%[", pos)
        if not open_s then break end

        local close_s, close_e = line:find("%]%]", open_e + 1)
        if not close_s then break end

        local inner = line:sub(open_e + 1, close_s - 1)
        local pipe  = inner:find("|", 1, true) -- 1-indexed pos within inner

        conceal(bufnr, row, open_s, open_e)   -- hide [[

        if pipe then
            -- hide "Title|", highlight alias
            conceal(bufnr, row, open_e + 1, open_e + pipe)
            highlight(bufnr, row, open_e + pipe + 1, close_s - 1, "NotesWikiLink")
        else
            highlight(bufnr, row, open_e + 1, close_s - 1, "NotesWikiLink")
        end

        conceal(bufnr, row, close_s, close_e)  -- hide ]]

        pos = close_e + 1
    end
end

-- ── inline code ───────────────────────────────────────────────────────────────

local function apply_inline_code(bufnr, row, line)
    local pos = 1
    while pos <= #line do
        local s = line:find("`", pos)
        if not s then break end

        -- Skip if part of ``` (adjacent backtick on either side)
        local prev = line:sub(s - 1, s - 1)
        local next = line:sub(s + 1, s + 1)
        if prev == "`" or next == "`" then
            pos = s + 1
        else
            -- Find matching closing single backtick
            local e = line:find("`", s + 1)
            if not e then break end
            -- Ensure closing backtick is also single
            local e_prev = line:sub(e - 1, e - 1)
            local e_next = line:sub(e + 1, e + 1)
            if e_prev ~= "`" and e_next ~= "`" then
                conceal(bufnr, row, s, s)         -- hide opening `
                highlight(bufnr, row, s + 1, e - 1, "NotesInlineCode")
                conceal(bufnr, row, e, e)         -- hide closing `
                pos = e + 1
            else
                pos = s + 1
            end
        end
    end
end

-- ── ==highlight== ─────────────────────────────────────────────────────────────

local function apply_mark_highlight(bufnr, row, line)
    local pos = 1
    while pos <= #line do
        local s, e = line:find("==([^=\n]+)==", pos)
        if not s then break end

        -- s,e span the entire ==content== match (1-indexed inclusive)
        -- ==   : positions s, s+1
        -- text : positions s+2 .. e-2
        -- ==   : positions e-1, e
        conceal(bufnr, row, s, s + 1)
        highlight(bufnr, row, s + 2, e - 2, "NotesHighlight")
        conceal(bufnr, row, e - 1, e)

        pos = e + 1
    end
end

-- ── main apply ────────────────────────────────────────────────────────────────

local function apply(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for lnum, line in ipairs(lines) do
        local row = lnum - 1
        apply_wikilinks(bufnr, row, line)
        apply_inline_code(bufnr, row, line)
        apply_mark_highlight(bufnr, row, line)
    end
end

-- ── public ────────────────────────────────────────────────────────────────────

function M.attach(bufnr)
    setup_highlights()
    apply(bufnr)
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer   = bufnr,
        callback = function() apply(bufnr) end,
    })
end

return M
