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

vim.keymap.set("n", "<leader>od", function()
    require("notes.daily").open()
end, { desc = "Notes: daily note" })

vim.api.nvim_create_user_command("NotesTagSearch", function()
    require("notes.tag").search()
end, { desc = "Search notes by tag" })

vim.api.nvim_create_user_command("NotesOrphans", function()
    require("notes.orphan").show()
end, { desc = "Show orphan notes (no backlinks)" })

vim.api.nvim_create_user_command("NotesInject", function()
    require("notes.note").inject()
end, { desc = "Inject a template into the current note" })

vim.api.nvim_create_user_command("NotesStats", function()
    require("notes.stats").show()
end, { desc = "Show vault statistics" })

vim.api.nvim_create_user_command("NotesExtract", function()
    require("notes.extract").extract()
end, { desc = "Extract visual selection into a new note" })
