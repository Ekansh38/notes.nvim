-- Extmark-based concealment for vault markdown. Works alongside treesitter.
--
-- Handles:
--   [[Title]]        → "Title"       (wikilink, underlined)
--   [[Title|Alias]]  → "Alias"       (aliased wikilink, underlined)
--   `code`           → code          (inline code, slight bg highlight)
--   ==text==         → text          (highlight mark, yellow)
--   YAML frontmatter → clean two-tone look, overrides treesitter YAML injection
--   ``` blocks       → full-width background via line_hl_group

local M = {}
local ns = vim.api.nvim_create_namespace("notes_conceal")

-- ── highlight groups ──────────────────────────────────────────────────────────
-- All Notes* groups use default = true so the user can override in their config.
-- The ColorScheme autocmd re-registers them after a theme change clears them.

local function setup_highlights()
    -- Wikilinks
    vim.api.nvim_set_hl(0, "@markup.link",  { link = "Underlined", default = true })
    vim.api.nvim_set_hl(0, "NotesWikiLink", { link = "@markup.link", default = true })

    -- ==highlight== — Visual is more neutral than Search across themes
    vim.api.nvim_set_hl(0, "NotesHighlight", { link = "Visual", default = true })

    -- Inline `code`
    vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { link = "CursorLine", default = true })
    vim.api.nvim_set_hl(0, "NotesInlineCode",             { link = "@markup.raw.markdown_inline", default = true })

    -- Fenced code block (full-width via line_hl_group)
    vim.api.nvim_set_hl(0, "NotesCodeBlock", { link = "CursorLine", default = true })
    vim.api.nvim_set_hl(0, "@markup.raw.delimiter.markdown", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "@label.markdown",                { link = "Comment", default = true })

    -- YAML frontmatter delimiters — only dim the --- lines, let the theme's
    -- YAML treesitter injection control key/value colors natively.
    vim.api.nvim_set_hl(0, "NotesYAMLDelim", { link = "Comment", default = true })
end

-- Re-apply after :colorscheme clears our custom groups
local _colorscheme_wired = false
local function ensure_colorscheme_autocmd()
    if _colorscheme_wired then return end
    _colorscheme_wired = true
    vim.api.nvim_create_autocmd("ColorScheme", { callback = setup_highlights })
end

-- ── low-level helpers ─────────────────────────────────────────────────────────
-- col_1, end_col_1: 1-indexed inclusive → converted to 0-indexed exclusive

local function conceal(bufnr, row, col_1, end_col_1)
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, col_1 - 1, {
        end_col = end_col_1,
        conceal = "",
    })
end

local function highlight(bufnr, row, col_1, end_col_1, hl_grp, prio)
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, col_1 - 1, {
        end_col  = end_col_1,
        hl_group = hl_grp,
        priority = prio,
    })
end

-- ── YAML frontmatter ──────────────────────────────────────────────────────────
-- Priority 150 beats treesitter (100) so our fg colors override YAML injection.

local function apply_frontmatter(bufnr, lines)
    if not lines[1] or lines[1] ~= "---" then return end

    -- Find the closing ---
    local fm_end = nil
    for i = 2, #lines do
        if lines[i] == "---" or lines[i] == "..." then
            fm_end = i
            break
        end
    end
    if not fm_end then return end

    -- Only dim the --- delimiters. Keys and values are left to the theme's
    -- YAML treesitter injection so each colorscheme looks natural.
    highlight(bufnr, 0,         1, #lines[1],      "NotesYAMLDelim", 150)
    highlight(bufnr, fm_end - 1, 1, #lines[fm_end], "NotesYAMLDelim", 150)
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
        local pipe  = inner:find("|", 1, true)

        conceal(bufnr, row, open_s, open_e)

        if pipe then
            conceal(bufnr, row, open_e + 1, open_e + pipe)
            highlight(bufnr, row, open_e + pipe + 1, close_s - 1, "NotesWikiLink")
        else
            highlight(bufnr, row, open_e + 1, close_s - 1, "NotesWikiLink")
        end

        conceal(bufnr, row, close_s, close_e)
        pos = close_e + 1
    end
end

-- ── inline code ───────────────────────────────────────────────────────────────

local function apply_inline_code(bufnr, row, line)
    local pos = 1
    while pos <= #line do
        local s = line:find("`", pos)
        if not s then break end

        local prev = line:sub(s - 1, s - 1)
        local next = line:sub(s + 1, s + 1)
        if prev == "`" or next == "`" then
            pos = s + 1
        else
            local e = line:find("`", s + 1)
            if not e then break end
            local e_prev = line:sub(e - 1, e - 1)
            local e_next = line:sub(e + 1, e + 1)
            if e_prev ~= "`" and e_next ~= "`" then
                conceal(bufnr, row, s, s)
                highlight(bufnr, row, s + 1, e - 1, "NotesInlineCode")
                conceal(bufnr, row, e, e)
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
        conceal(bufnr, row, s, s + 1)
        highlight(bufnr, row, s + 2, e - 2, "NotesHighlight")
        conceal(bufnr, row, e - 1, e)
        pos = e + 1
    end
end

-- ── fenced code blocks ────────────────────────────────────────────────────────

local function apply_code_blocks(bufnr, lines)
    local in_fence = false
    for lnum, line in ipairs(lines) do
        local row = lnum - 1
        if line:match("^%s*```") then
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
                line_hl_group = "NotesCodeBlock",
                priority      = 50,
            })
            in_fence = not in_fence
        elseif in_fence then
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
                line_hl_group = "NotesCodeBlock",
                priority      = 50,
            })
        end
    end
end

-- ── main apply ────────────────────────────────────────────────────────────────

local function apply(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    apply_frontmatter(bufnr, lines)
    apply_code_blocks(bufnr, lines)
    for lnum, line in ipairs(lines) do
        local row = lnum - 1
        apply_wikilinks(bufnr, row, line)
        apply_inline_code(bufnr, row, line)
        apply_mark_highlight(bufnr, row, line)
    end
end

-- ── public ────────────────────────────────────────────────────────────────────

local _timers = {}  -- bufnr → pending timer handle

local function apply_debounced(bufnr)
    local t = _timers[bufnr]
    if t then t:stop() end
    _timers[bufnr] = vim.defer_fn(function()
        _timers[bufnr] = nil
        if vim.api.nvim_buf_is_valid(bufnr) then
            apply(bufnr)
        end
    end, 80)  -- 80 ms: fast enough to feel instant, slow enough to skip mid-word keystrokes
end

function M.attach(bufnr)
    setup_highlights()
    ensure_colorscheme_autocmd()
    apply(bufnr)
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer   = bufnr,
        callback = function() apply_debounced(bufnr) end,
    })
end

return M
