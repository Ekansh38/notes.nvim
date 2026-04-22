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

-- ── callout type definitions ──────────────────────────────────────────────────
-- icon: nerd font glyph   hl: which group controls the accent color

local CALLOUT_DEFS = {
    note      = { icon = "󰋽", hl = "DiagnosticInfo"  },
    info      = { icon = "",  hl = "DiagnosticInfo"  },
    abstract  = { icon = "󰈙", hl = "DiagnosticInfo"  },
    summary   = { icon = "󰈙", hl = "DiagnosticInfo"  },
    tip       = { icon = "",  hl = "DiagnosticHint"  },
    hint      = { icon = "",  hl = "DiagnosticHint"  },
    important = { icon = "",  hl = "DiagnosticHint"  },
    success   = { icon = "",  hl = "DiagnosticOk"   },
    done      = { icon = "",  hl = "DiagnosticOk"   },
    check     = { icon = "",  hl = "DiagnosticOk"   },
    question  = { icon = "",  hl = "DiagnosticWarn"  },
    warning   = { icon = "",  hl = "DiagnosticWarn"  },
    caution   = { icon = "",  hl = "DiagnosticWarn"  },
    attention = { icon = "",  hl = "DiagnosticWarn"  },
    failure   = { icon = "",  hl = "DiagnosticError" },
    danger    = { icon = "",  hl = "DiagnosticError" },
    error     = { icon = "",  hl = "DiagnosticError" },
    bug       = { icon = "",  hl = "DiagnosticError" },
    quote     = { icon = "󱆀", hl = "NotesCallout"   },
    cite      = { icon = "󱆀", hl = "NotesCallout"   },
    example   = { icon = "",  hl = "Special"         },
}

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

    -- YAML frontmatter delimiters
    vim.api.nvim_set_hl(0, "NotesYAMLDelim", { link = "Comment", default = true })

    -- Dead wikilinks — [[NoteThатDoesntExist]] shown in warning color
    vim.api.nvim_set_hl(0, "NotesDeadLink", { link = "DiagnosticWarn", default = true })

    -- Callout blocks
    vim.api.nvim_set_hl(0, "NotesCallout",   { link = "Comment",    default = true })
    vim.api.nvim_set_hl(0, "NotesCalloutBg", { link = "CursorLine", default = true })

    -- Horizontal rule (--- in body)
    vim.api.nvim_set_hl(0, "NotesHRule", { link = "Comment", default = true })

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

        -- Strip alias and heading to get the bare note title for lookup
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

-- ── callout blocks ────────────────────────────────────────────────────────────
-- Detects Obsidian-style callouts:
--   >[!quote]                 ← header line
--   >[!quote] Custom Title    ← header with optional title override
--   > body text               ← body lines
--
-- Header gets: colored line background + "icon  Title" virt_text prepended
-- Body gets: same background, `> ` prefix replaced with `│ ` via conceal

local function apply_callouts(bufnr, lines)
    local i = 1
    while i <= #lines do
        local line = lines[i]
        local raw_type, rest = line:match("^>%s*%[!(%w+)%]%s*(.*)$")

        if raw_type then
            local def   = CALLOUT_DEFS[raw_type:lower()]
            local icon  = def and def.icon or ""
            local hl    = def and def.hl   or "NotesCallout"
            local row   = i - 1

            -- Capitalize the displayed type name (or use custom title if present)
            local display_title = (rest ~= "" and rest)
                or (raw_type:sub(1,1):upper() .. raw_type:sub(2):lower())

            -- Full-width background on header line
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
                line_hl_group = "NotesCalloutBg",
                priority      = 60,
            })

            -- Conceal >[!type] or >[!type] Title — everything up to end of line
            -- by hiding `>[!` and `]` to leave just the type name, then overlaying
            -- with icon + title using virt_text at the start of the line.
            local header_end = #line
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
                end_col      = header_end,
                conceal      = "",
            })
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
                virt_text          = { { " " .. icon .. "  " .. display_title, hl } },
                virt_text_pos      = "overlay",
                priority           = 61,
            })

            -- Walk following `> ` body lines
            i = i + 1
            while i <= #lines do
                local body = lines[i]
                if not body:match("^>") then break end

                local brow = i - 1
                vim.api.nvim_buf_set_extmark(bufnr, ns, brow, 0, {
                    line_hl_group = "NotesCalloutBg",
                    priority      = 60,
                })

                -- Replace `> ` prefix (the `>` + optional space) with `│`
                local gt_end = body:match("^(>%s?)") and #body:match("^(>%s?)") or 1
                vim.api.nvim_buf_set_extmark(bufnr, ns, brow, 0, {
                    end_col = gt_end,
                    conceal = "│",
                })

                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

-- ── markdown links ────────────────────────────────────────────────────────────
-- [text](url) → shows "text↗", hides [ and ](url) as 0-width so long URLs
-- never wrap to blank visual lines.
-- Skips wikilinks ([[) and image links (![ ).

local function apply_md_links(bufnr, row, line)
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

        -- Find the closing ] followed immediately by (
        local bracket_e = line:find("%]%(", bracket_s + 1)
        if not bracket_e then break end

        -- Make sure no nested [ between open and close
        local inner_bracket = line:find("%[", bracket_s + 1, true)
        if inner_bracket and inner_bracket < bracket_e then
            pos = bracket_s + 1
            goto next
        end

        -- Find matching ) tracking depth (URLs can contain parens)
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

        -- Conceal the opening [  (0-width)
        conceal(bufnr, row, bracket_s, bracket_s)
        -- Insert ↗ inline right before ](url) so it appears after the link text
        vim.api.nvim_buf_set_extmark(bufnr, ns, row, bracket_e - 1, {
            virt_text     = { { "↗", "Comment" } },
            virt_text_pos = "inline",
        })
        -- Conceal ](url) entirely as 0-width — prevents URL from wrapping to blank lines
        vim.api.nvim_buf_set_extmark(bufnr, ns, row, bracket_e - 1, {
            end_col = paren_e,
            conceal = "",
        })

        pos = paren_e + 1
        ::next::
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

-- ── horizontal rules ─────────────────────────────────────────────────────────
-- Renders --- / *** / ___ body lines as a visual divider.
-- Skips the two frontmatter delimiter lines (--- at top of file).

local function apply_hr(bufnr, lines)
    -- Locate frontmatter end so we don't touch its --- delimiters
    local fm_end = 0
    if lines[1] == "---" then
        for i = 2, #lines do
            if lines[i] == "---" or lines[i] == "..." then
                fm_end = i
                break
            end
        end
    end

    local bar = string.rep("─", 120)   -- wide enough for any reasonable window
    for lnum = fm_end + 1, #lines do
        local line = lines[lnum]
        -- Match ---, ***, ___ (3 or more chars, nothing else on the line)
        if line:match("^%-%-%-+$") or line:match("^%*%*%*+$") or line:match("^___%+$") then
            local row = lnum - 1
            -- Conceal the raw --- so it takes 0 width
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
                end_col = #line,
                conceal = "",
            })
            -- Overlay with a ─ line that fills the window
            vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
                virt_text     = { { bar, "NotesHRule" } },
                virt_text_pos = "overlay",
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
    apply_callouts(bufnr, lines)
    apply_hr(bufnr, lines)
    for lnum, line in ipairs(lines) do
        local row = lnum - 1
        apply_wikilinks(bufnr, row, line)
        apply_md_links(bufnr, row, line)
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
