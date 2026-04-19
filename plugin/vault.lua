-- Global commands — work from any buffer, any filetype
vim.api.nvim_create_user_command("VaultNew", function()
    require("vault.note").new()
end, { desc = "Create a new vault note" })

vim.api.nvim_create_user_command("VaultDaily", function()
    require("vault.daily").open()
end, { desc = "Open today's daily note" })

vim.api.nvim_create_user_command("VaultBacklinks", function()
    require("vault.backlink").show()
end, { desc = "Show backlinks for current note" })

vim.api.nvim_create_user_command("VaultRename", function()
    require("vault.rename").rename()
end, { desc = "Rename current note and update all links" })
