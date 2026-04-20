local M = {}

M.config = {
    vault_path      = vim.fn.expand("~/Documents/EkanshVault"),
    templates_dir   = "Templates",
    daily_dir       = "Daily",
    daily_template  = "Daily Note Template.md",
    git_auto_commit = false,  -- stage on save, commit on exit
    git_auto_push   = false,  -- push on exit (adds ~1-3s delay)
}

-- Word count for the current vault buffer (excludes frontmatter).
-- Use in lualine: require("notes").word_count()
function M.word_count()
    if vim.bo.filetype ~= "markdown" then return "" end
    local bufname = vim.api.nvim_buf_get_name(0)
    if not bufname:find(M.config.vault_path, 1, true) then return "" end

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    -- Skip frontmatter
    local start = 1
    if lines[1] == "---" then
        for i = 2, #lines do
            if lines[i] == "---" or lines[i] == "..." then
                start = i + 1
                break
            end
        end
    end

    local count = 0
    for i = start, #lines do
        for _ in lines[i]:gmatch("%S+") do count = count + 1 end
    end
    return count > 0 and (count .. " words") or ""
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    require("notes.git").setup()

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

            -- nvim-treesitter lazy-loads on BufReadPost, so the buffer that
            -- triggered it already missed that event. Start treesitter manually
            -- so code block injections and syntax highlighting actually work.
            if not vim.treesitter.highlighter.active[bufnr] then
                pcall(vim.treesitter.start, bufnr, "markdown")
            end

            -- Vault-specific comfort settings
            vim.opt_local.conceallevel = 2      -- required for extmark conceal to hide brackets
            vim.opt_local.wrap         = true   -- long lines wrap instead of scrolling sideways
            vim.opt_local.linebreak    = true   -- wrap at word boundaries, not mid-word
            vim.opt_local.spell        = true   -- spell checking
            vim.opt_local.spelllang    = "en_us"

            -- Extmark-based concealment (wikilinks, inline code, ==highlight==)
            require("notes.conceal").attach(bufnr)

            local o = { buffer = true, silent = true }
            vim.keymap.set("n", "gf",         require("notes.link").follow,        vim.tbl_extend("force", o, { desc = "Follow wikilink" }))
            vim.keymap.set("n", "K",          require("notes.preview").show,       vim.tbl_extend("force", o, { desc = "Notes: preview wikilink" }))
            vim.keymap.set("n", "<leader>on", require("notes.note").new,           vim.tbl_extend("force", o, { desc = "Notes: new note" }))
            vim.keymap.set("n", "<leader>ob", require("notes.backlink").show,      vim.tbl_extend("force", o, { desc = "Notes: backlinks" }))
            vim.keymap.set("n", "<leader>or", require("notes.rename").rename,      vim.tbl_extend("force", o, { desc = "Notes: rename + relink" }))
            vim.keymap.set("n", "<leader>ot", require("notes.tag").search,         vim.tbl_extend("force", o, { desc = "Notes: tag search" }))
            vim.keymap.set("n", "<leader>oo", require("notes.orphan").show,        vim.tbl_extend("force", o, { desc = "Notes: orphan notes" }))
            vim.keymap.set("n", "<leader>oi", require("notes.note").inject,        vim.tbl_extend("force", o, { desc = "Notes: inject template" }))
            vim.keymap.set("n", "<leader>oh", require("notes.outline").show,       vim.tbl_extend("force", o, { desc = "Notes: heading outline" }))
            vim.keymap.set("n", "<leader>os", require("notes.stats").show,         vim.tbl_extend("force", o, { desc = "Notes: vault stats" }))
            vim.keymap.set("n", "<leader>op", require("notes.url").paste_as_link,  vim.tbl_extend("force", o, { desc = "Notes: paste URL as link" }))
            vim.keymap.set("v", "<leader>oe", require("notes.extract").extract,    vim.tbl_extend("force", o, { desc = "Notes: extract selection to note" }))
            vim.keymap.set("n", "[d",         function() require("notes.daily").navigate(-1) end, vim.tbl_extend("force", o, { desc = "Notes: previous daily note" }))
            vim.keymap.set("n", "]d",         function() require("notes.daily").navigate(1) end,  vim.tbl_extend("force", o, { desc = "Notes: next daily note" }))
        end,
    })
end

return M
