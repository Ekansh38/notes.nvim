-- Notes-specific extmark concealment (vault markdown only).
-- render-markdown.nvim handles standard MD (headings, code, lists, callouts, HR, links).
-- This module handles notes-only syntax:
--   [[Title]]        → "Title"       (wikilink, underlined)
--   [[Title|Alias]]  → "Alias"       (aliased wikilink)
--   ==text==         → text          (Obsidian highlight mark)
--   YAML frontmatter → dimmed delimiters

local M = {}
local ns = vim.api.nvim_create_namespace("notes_conceal")

-- ── highlight groups ──────────────────────────────────────────────────────────

local function setup_highlights()
    vim.api.nvim_set_hl(0, "@markup.link",  { link = "Underlined",    default = true })
    vim.api.nvim_set_hl(0, "NotesWikiLink", { link = "@markup.link",  default = true })
    vim.api.nvim_set_hl(0, "NotesDeadLink", { link = "DiagnosticWarn", default = true })
    vim.api.nvim_set_hl(0, "NotesHighlight",{ link = "Visual",         default = true })
    vim.api.nvim_set_hl(0, "NotesYAMLDelim",{ link = "Comment",        default = true })
end

local _colorscheme_wired = false
local function ensure_colorscheme_autocmd()
    if _colorscheme_wired then return end
    _colorscheme_wired = true
    vim.api.nvim_create_autocmd("ColorScheme", { callback = setup_highlights })
end

-- ── low-level helpers ─────────────────────────────────────────────────────────

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

local function apply_frontmatter(bufnr, lines)
    if not lines[1] or lines[1] ~= "---" then return end
    local fm_end = nil
    for i = 2, #lines do
        if lines[i] == "---" or lines[i] == "..." then
            fm_end = i
            break
        end
    end
    if not fm_end then return end
    highlight(bufnr, 0,         1, #lines[1],      "NotesYAMLDelim", 150)
    highlight(bufnr, fm_end - 1, 1, #lines[fm_end], "NotesYAMLDelim", 150)
end

-- ── wikilinks ─────────────────────────────────────────────────────────────────

local function apply_wikilinks(bufnr, row, line)
    local util = require("notes.util")
    local pos  = 1
    while pos <= #line do
        local open_s, open_e = line:find("%[%[", pos)
        if not open_s then break end

        local close_s, close_e = line:find("%]%]", open_e + 1)
        if not close_s then break end

        local inner = line:sub(open_e + 1, close_s - 1)
        local pipe  = inner:find("|", 1, true)
        local hash  = inner:find("#", 1, true)

        local lookup_end   = math.min(pipe or #inner + 1, hash or #inner + 1) - 1
        local lookup_title = vim.trim(inner:sub(1, lookup_end))
        local hl           = util.find_note(lookup_title) and "NotesWikiLink" or "NotesDeadLink"

        conceal(bufnr, row, open_s, open_e)
        if pipe then
            conceal(bufnr, row, open_e + 1, open_e + pipe)
            highlight(bufnr, row, open_e + pipe + 1, close_s - 1, hl)
        else
            highlight(bufnr, row, open_e + 1, close_s - 1, hl)
        end
        conceal(bufnr, row, close_s, close_e)
        pos = close_e + 1
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

-- ── main apply ────────────────────────────────────────────────────────────────

local function apply(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    apply_frontmatter(bufnr, lines)
    for lnum, line in ipairs(lines) do
        local row = lnum - 1
        apply_wikilinks(bufnr, row, line)
        apply_mark_highlight(bufnr, row, line)
    end
end

-- ── public ────────────────────────────────────────────────────────────────────

local _timers = {}

local function apply_debounced(bufnr)
    local t = _timers[bufnr]
    if t then t:stop() end
    _timers[bufnr] = vim.defer_fn(function()
        _timers[bufnr] = nil
        if vim.api.nvim_buf_is_valid(bufnr) then apply(bufnr) end
    end, 80)
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
