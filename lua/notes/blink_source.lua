-- blink.cmp source for [[wikilinks]] and [[Note#Heading]] references.
--
-- Two modes detected from what's typed after [[:
--   [[Note Title           → complete note titles (File/Text kind)
--   [[Note Title#query     → complete headings from that note (Reference kind)
--
-- Uses ".*%[%[(.*)$" (rightmost [[) so multi-link lines work correctly.
-- Bails if the captured text contains ]] (wikilink already closed).

local Source = {}

function Source.new()
    return setmetatable({}, { __index = Source })
end

function Source:get_trigger_characters()
    return { "[" }
end

function Source:get_completions(ctx, callback)
    local before = ctx.line:sub(1, ctx.cursor[2])

    -- Find the RIGHTMOST [[ before cursor (.*%[%[ is greedy, finds last [[)
    local after_bracket = before:match(".*%[%[(.*)$")

    -- Bail if no [[ found or if it's already closed (contains ]])
    if not after_bracket or after_bracket:match("%]%]") then
        callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
        return
    end

    -- 0-indexed col right after [[
    local bracket_col = ctx.cursor[2] - #after_bracket
    local row_0       = ctx.cursor[1] - 1

    -- ── Mode 1: heading reference — [[Note Title#query ────────────────────────
    -- note_part = "Note Title", heading_q = "query" (or "" if just typed #)
    local note_part, heading_q = after_bracket:match("^([^#]*)#(.*)$")

    if note_part and vim.trim(note_part) ~= "" then
        local note_title = vim.trim(note_part)
        local path       = require("notes.util").find_note(note_title)

        if not path then
            -- Note doesn't exist yet — no headings to offer
            callback({ is_incomplete_forward = true, is_incomplete_backward = false, items = {} })
            return
        end

        local file_lines = vim.fn.readfile(path)
        local items      = {}
        local lower_q    = heading_q:lower()
        -- Replace start is right after the # character
        local h_start    = bracket_col + #note_part + 1  -- 0-indexed

        for _, line in ipairs(file_lines) do
            local _, title = line:match("^(#+)%s+(.+)$")
            if title and (lower_q == "" or title:lower():find(lower_q, 1, true)) then
                items[#items + 1] = {
                    label            = title,
                    filterText       = title,
                    kind             = vim.lsp.protocol.CompletionItemKind.Reference,
                    insertTextFormat = 1,
                    textEdit = {
                        newText = title,
                        range   = {
                            start   = { line = row_0, character = h_start },
                            ["end"] = { line = row_0, character = ctx.cursor[2] },
                        },
                    },
                    labelDetails = { description = "heading" },
                }
            end
        end

        callback({ is_incomplete_forward = true, is_incomplete_backward = false, items = items })
        return
    end

    -- ── Mode 2: note title — [[query ──────────────────────────────────────────
    local util   = require("notes.util")
    local notes  = util.all_notes_for_completion()
    local pinned = util.pinned_set()
    local items  = {}

    -- Sort: pinned first, then existing notes, then ghost notes
    table.sort(notes, function(a, b)
        local ap = pinned[a.title] and 1 or 0
        local bp = pinned[b.title] and 1 or 0
        if ap ~= bp then return ap > bp end
        if a.exists ~= b.exists then return a.exists end
        return a.title < b.title
    end)

    for _, note in ipairs(notes) do
        items[#items + 1] = {
            label            = note.title,
            kind             = note.exists
                and vim.lsp.protocol.CompletionItemKind.File
                or  vim.lsp.protocol.CompletionItemKind.Text,
            insertTextFormat = 1,
            textEdit = {
                newText = note.title,
                range   = {
                    start   = { line = row_0, character = bracket_col },
                    ["end"] = { line = row_0, character = ctx.cursor[2] },
                },
            },
            labelDetails = {
                description = pinned[note.title] and "pinned" or (note.exists and "note" or "not created")
            },
        }
    end

    callback({ is_incomplete_forward = true, is_incomplete_backward = false, items = items })
end

return Source
