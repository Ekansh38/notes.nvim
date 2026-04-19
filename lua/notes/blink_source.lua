-- blink.cmp completion source for [[wikilinks]]
-- Triggers on "[", activates when "[[" precedes the cursor.
--
-- Key design decisions:
--   - textEdit with explicit range (from after [[ to cursor) so blink replaces
--     the FULL typed query, not just the last word boundary. Fixes multi-word matching.
--   - is_incomplete_forward = true so blink re-requests on each keystroke.
--   - Ghost notes (linked but uncreated) shown with kind=Text, real notes with kind=File.
local Source = {}

function Source.new()
    return setmetatable({}, { __index = Source })
end

function Source:get_trigger_characters()
    return { "[" }
end

function Source:get_completions(ctx, callback)
    -- ctx.cursor = { row (1-indexed), col (0-indexed) }
    local before = ctx.line:sub(1, ctx.cursor[2])

    -- Only activate when [[ appears before cursor with no ]] in between
    local after_bracket = before:match("%[%[(.*)$")
    if not after_bracket then
        callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
        return
    end

    -- The col (0-indexed) right after [[  — this is where replacement starts
    local bracket_col = ctx.cursor[2] - #after_bracket
    local row_0       = ctx.cursor[1] - 1 -- LSP uses 0-indexed lines

    local notes = require("notes.util").all_notes_for_completion()
    local items  = {}

    for _, note in ipairs(notes) do
        items[#items + 1] = {
            label            = note.title,
            -- File = real note, Text = ghost (linked but not yet created)
            kind             = note.exists
                and vim.lsp.protocol.CompletionItemKind.File
                or  vim.lsp.protocol.CompletionItemKind.Text,
            insertTextFormat = 1, -- PlainText
            -- Explicit range: replaces everything typed after [[ up to cursor.
            -- This is what fixes multi-word queries — blink no longer resets
            -- the query at each space boundary.
            textEdit = {
                newText = note.title,
                range   = {
                    start   = { line = row_0, character = bracket_col },
                    ["end"] = { line = row_0, character = ctx.cursor[2] },
                },
            },
            labelDetails = { description = note.exists and "note" or "not created" },
        }
    end

    callback({
        -- Re-request on every keystroke so our own pre-filtering stays current
        is_incomplete_forward  = true,
        is_incomplete_backward = false,
        items                  = items,
    })
end

return Source
