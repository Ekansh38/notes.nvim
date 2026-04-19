-- blink.cmp completion source for [[wikilinks]]
-- Triggers on "[", but only produces items when "[[" precedes the cursor.
local Source = {}

function Source.new()
    return setmetatable({}, { __index = Source })
end

function Source:get_trigger_characters()
    return { "[" }
end

function Source:get_completions(ctx, callback)
    -- ctx.cursor is { row, col } 0-indexed col
    local before = ctx.line:sub(1, ctx.cursor[2])

    -- Only complete when [[ appears before cursor with no ]] in between.
    -- Pattern: "[[" followed by non-] characters up to end of string.
    if not before:match("%[%[[^%]]*$") then
        callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
        return
    end

    local titles = require("notes.util").all_titles()
    local items  = {}
    for _, title in ipairs(titles) do
        items[#items + 1] = {
            label            = title,
            kind             = vim.lsp.protocol.CompletionItemKind.File,
            -- blink replaces the keyword prefix (what was typed after [[)
            -- insertText completes the rest of the title and closes the brackets
            insertText       = title,  -- mini.pairs already closed the ]]
            insertTextFormat = 1, -- PlainText
            labelDetails     = { description = "note" },
        }
    end

    callback({
        is_incomplete_forward  = false,
        is_incomplete_backward = false,
        items                  = items,
    })
end

return Source
