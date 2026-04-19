local M = {}

M.config = {
    vault_path     = vim.fn.expand("~/Documents/EkanshVault"),
    templates_dir  = "Templates",
    daily_dir      = "Daily",
    daily_template = "Daily Note Template.md",
}

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    -- Invalidate the note index whenever a vault .md file is written or deleted
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufDelete" }, {
        pattern  = M.config.vault_path .. "/**/*.md",
        callback = function() require("vault.util").invalidate() end,
    })

    -- Buffer-local keymaps: only for markdown files inside the vault
    vim.api.nvim_create_autocmd("FileType", {
        pattern  = "markdown",
        callback = function()
            local bufname = vim.api.nvim_buf_get_name(0)
            if not bufname:find(M.config.vault_path, 1, true) then return end

            local o = { buffer = true, silent = true }
            vim.keymap.set("n", "gf",         require("vault.link").follow,     vim.tbl_extend("force", o, { desc = "Follow wikilink" }))
            vim.keymap.set("n", "<leader>vn", require("vault.note").new,        vim.tbl_extend("force", o, { desc = "Vault: new note" }))
            vim.keymap.set("n", "<leader>vd", require("vault.daily").open,      vim.tbl_extend("force", o, { desc = "Vault: daily note" }))
            vim.keymap.set("n", "<leader>vb", require("vault.backlink").show,   vim.tbl_extend("force", o, { desc = "Vault: backlinks" }))
            vim.keymap.set("n", "<leader>vr", require("vault.rename").rename,   vim.tbl_extend("force", o, { desc = "Vault: rename + relink" }))
        end,
    })
end

return M
