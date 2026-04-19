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
        callback = function() require("notes.util").invalidate() end,
    })

    -- Buffer-local setup: only for markdown files inside the vault
    vim.api.nvim_create_autocmd("FileType", {
        pattern  = "markdown",
        callback = function()
            local bufname = vim.api.nvim_buf_get_name(0)
            if not bufname:find(M.config.vault_path, 1, true) then return end

            local bufnr = vim.api.nvim_get_current_buf()

            -- Extmark-based concealment (wikilinks, inline code, ==highlight==)
            require("notes.conceal").attach(bufnr)

            local o = { buffer = true, silent = true }
            vim.keymap.set("n", "gf",         require("notes.link").follow,    vim.tbl_extend("force", o, { desc = "Follow wikilink" }))
            vim.keymap.set("n", "<leader>on", require("notes.note").new,       vim.tbl_extend("force", o, { desc = "Notes: new note" }))
            vim.keymap.set("n", "<leader>ob", require("notes.backlink").show,  vim.tbl_extend("force", o, { desc = "Notes: backlinks" }))
            vim.keymap.set("n", "<leader>or", require("notes.rename").rename,  vim.tbl_extend("force", o, { desc = "Notes: rename + relink" }))
        end,
    })
end

return M
