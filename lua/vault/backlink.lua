local M = {}

function M.show()
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname == "" then
        vim.notify("vault: buffer has no file", vim.log.levels.WARN)
        return
    end

    local cfg   = require("vault").config
    local title = vim.fn.fnamemodify(bufname, ":t:r")

    -- "[[Title" catches both [[Title]] and [[Title|alias]] without regex.
    -- grep_string passes --fixed-strings to ripgrep so special chars are safe.
    require("telescope.builtin").grep_string({
        prompt_title = "Backlinks → " .. title,
        search       = "[[" .. title,
        search_dirs  = { cfg.vault_path },
        use_regex    = false,
    })
end

return M
