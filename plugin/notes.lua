-- Global commands and keymaps — available from any buffer, any filetype.

vim.api.nvim_create_user_command("NotesNew", function()
    require("notes.note").new()
end, { desc = "Create a new note" })

vim.api.nvim_create_user_command("NotesDaily", function()
    require("notes.daily").open()
end, { desc = "Open today's daily note" })

vim.api.nvim_create_user_command("NotesBacklinks", function()
    require("notes.backlink").show()
end, { desc = "Show backlinks for current note" })

vim.api.nvim_create_user_command("NotesRename", function()
    require("notes.rename").rename()
end, { desc = "Rename current note and update all links" })

-- <leader>od is global: open daily note from anywhere, then <C-o> to jump back.
-- lazy = false ensures this is always loaded at startup regardless of filetype.
vim.keymap.set("n", "<leader>od", function()
    require("notes.daily").open()
end, { desc = "Notes: daily note (global)" })
