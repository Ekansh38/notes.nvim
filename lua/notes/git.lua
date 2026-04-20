-- Auto-commit vault notes to git.
--
-- Strategy:
--   VimLeavePre → git add -A          (stage everything, sync, instant)
--               → git commit -m "..."  (sync, fast — local only)
--               → git push             (detached process — survives nvim exit, zero wait)
--
-- Enable in setup():
--   require("notes").setup({ git_auto_commit = true, git_auto_push = true })

local M = {}

function M.setup()
    local cfg = require("notes").config
    if not cfg.git_auto_commit then return end

    -- Silently verify the vault is a git repo before wiring autocmds
    local result = vim.system({ "git", "-C", cfg.vault_path, "rev-parse", "--git-dir" }):wait(2000)
    if result.code ~= 0 then
        vim.notify("notes: vault is not a git repo — git_auto_commit disabled", vim.log.levels.WARN)
        return
    end

    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            local vault = cfg.vault_path

            -- Stage everything in the vault
            vim.system({ "git", "-C", vault, "add", "-A" }):wait(3000)

            -- Commit (fails silently if nothing changed)
            local msg = "notes: " .. os.date("%Y-%m-%d %H:%M")
            vim.system({ "git", "-C", vault, "commit", "-m", msg }):wait(5000)

            -- Push in a detached process — nvim exits immediately, push runs in background
            if cfg.git_auto_push then
                vim.fn.jobstart({ "git", "-C", vault, "push" }, { detach = true })
            end
        end,
    })
end

return M
