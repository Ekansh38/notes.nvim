-- blink.cmp completion source for #tags (body) and YAML frontmatter tag lists.
--
-- Two contexts:
--   Body:        Type #dsa  → shows cs/dsa/data-structure (substring match)
--   Frontmatter: Type "  - " under tags: → shows all tags (no # needed)
--
-- Substring filtering is done server-side so blink's client-side keyword
-- boundary detection (which splits on "/") can't drop hierarchical tags.

local Source = {}

function Source.new()
    return setmetatable({}, { __index = Source })
end

function Source:get_trigger_characters()
    return { "#", "-" }
end

-- Returns { query, start_col (0-indexed) } when the cursor is on a list-item
-- line inside a frontmatter "tags:" section.
-- Returns { partial = true } when just "-" is typed (no space yet) but we
-- are in the right section — keeps blink alive so the next keypress re-queries.
-- Returns nil when not in a frontmatter tags context.
local function check_frontmatter_tags(ctx)
    local before = ctx.line:sub(1, ctx.cursor[2])
    local row_0  = ctx.cursor[1] - 1

    -- "  - query" (space after dash → real list item)
    local prefix, query = before:match("^(%s*%-%s+)(.*)")
    -- "  -" (dash just typed, space not yet)
    local partial = not prefix and (before:match("^%s*%-$") ~= nil)

    if not prefix and not partial then return nil end

    -- Verify we're inside a frontmatter tags: section by scanning upward
    local bufnr = vim.api.nvim_get_current_buf()
    if row_0 == 0 then return nil end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row_0 + 1, false)
    -- lines[i] in Lua = buffer row i-1 (lines[1] = row 0)

    if lines[1] ~= "---" then return nil end  -- not a frontmatter file

    for lua_i = row_0 + 1, 2, -1 do
        local line = lines[lua_i]
        if line == "---" or line == "..." then return nil end   -- hit boundary
        if line:match("^tags:") then
            if partial then return { partial = true } end
            return { query = query, start = #prefix }  -- start is 0-indexed
        end
        if line:match("^%a%w*:") then return nil end  -- different FM key above
    end

    return nil
end

local function make_items(tags, lower_q, row_0, replace_start, replace_end)
    local items = {}
    for _, tag in ipairs(tags) do
        -- Substring match: "dsa" matches "cs/dsa/data-structure"
        if lower_q == "" or tag:lower():find(lower_q, 1, true) then
            items[#items + 1] = {
                label            = tag,
                filterText       = tag,   -- blink uses this for its own scoring
                kind             = vim.lsp.protocol.CompletionItemKind.Keyword,
                insertTextFormat = 1,
                textEdit = {
                    newText = tag,
                    range   = {
                        start   = { line = row_0, character = replace_start },
                        ["end"] = { line = row_0, character = replace_end },
                    },
                },
                labelDetails = { description = "tag" },
            }
        end
    end
    return items
end

function Source:get_completions(ctx, callback)
    local before = ctx.line:sub(1, ctx.cursor[2])
    local row_0  = ctx.cursor[1] - 1

    -- Inside an unclosed [[ the # is a heading separator, not a tag trigger.
    -- Bail immediately and let blink_source handle the [[Note#heading]] context.
    local wb = before:match(".*%[%[(.*)$")
    if wb and not wb:match("%]%]") then
        callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
        return
    end

    -- ── Context 1: frontmatter "  - <query>" ─────────────────────────────────
    local fm = check_frontmatter_tags(ctx)
    if fm then
        if fm.partial then
            -- Just "-" typed, no space yet. Keep source alive.
            callback({ is_incomplete_forward = true, is_incomplete_backward = false, items = {} })
            return
        end

        local all_tags = require("notes.util").all_tag_names()
        local items    = make_items(all_tags, fm.query:lower(), row_0, fm.start, ctx.cursor[2])
        callback({ is_incomplete_forward = true, is_incomplete_backward = false, items = items })
        return
    end

    -- ── Context 2: body "#tag" ────────────────────────────────────────────────
    -- Must end with #<tag-chars>, # preceded by whitespace or col 0.
    local tag_suffix = before:match("#([%w%-_/]*)$")
    if not tag_suffix then
        callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
        return
    end

    local hash_col_1 = #before - #tag_suffix  -- 1-indexed position of #

    if hash_col_1 > 1 then
        local char_before = before:sub(hash_col_1 - 1, hash_col_1 - 1)
        if not char_before:match("%s") then
            callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
            return
        end
    end

    -- Reject markdown headings: "## Title"
    if before:match("^#+%s") then
        callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
        return
    end

    local hash_col_0 = hash_col_1 - 1
    local all_tags   = require("notes.util").all_tag_names()
    local items      = make_items(all_tags, tag_suffix:lower(), row_0, hash_col_0 + 1, ctx.cursor[2])

    callback({ is_incomplete_forward = true, is_incomplete_backward = false, items = items })
end

return Source
