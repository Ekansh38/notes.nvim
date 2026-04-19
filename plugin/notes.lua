-- Global commands — work from any buffer, any filetype
vim.api.nvim_create_user_command("VaultNew", function()
    require("notes.note").new()
end, { desc = "Create a new note" })

vim.api.nvim_create_user_command("VaultDaily", function()
    require("notes.daily").open()
end, { desc = "Open today's daily note" })

vim.api.nvim_create_user_command("VaultBacklinks", function()
    require("notes.backlink").show()
end, { desc = "Show backlinks for current note" })

vim.api.nvim_create_user_command("VaultRename", function()
    require("notes.rename").rename()
end, { desc = "Rename current note and update all links" })
