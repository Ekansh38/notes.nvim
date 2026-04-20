-- Smart URL paste: reads system clipboard, fetches page <title>, inserts [Title](url).
-- Bound to <leader>op in vault markdown buffers.
-- Falls back to normal paste if clipboard is not a URL.

local M = {}

local URL_PAT = "^https?://[%S]+"

function M.paste_as_link()
    local clip = vim.trim(vim.fn.getreg("+"))

    if not clip:match(URL_PAT) then
        vim.cmd("normal! p")
        return
    end

    local url = clip
    vim.notify("notes: fetching title…", vim.log.levels.INFO)

    vim.system(
        { "curl", "-s", "-L", "--max-time", "8", "-A", "Mozilla/5.0", url },
        { text = true },
        function(res)
            vim.schedule(function()
                local title = ""
                if res.code == 0 and res.stdout then
                    local raw = res.stdout:match("<title[^>]*>([^<]+)</title>")
                    if raw then
                        title = raw
                            :gsub("&amp;",  "&")
                            :gsub("&lt;",   "<")
                            :gsub("&gt;",   ">")
                            :gsub("&quot;", '"')
                            :gsub("&#(%d+);", function(n)
                                local c = tonumber(n)
                                return (c and c < 128) and string.char(c) or ""
                            end)
                            :gsub("%s+", " ")
                        title = vim.trim(title)
                    end
                end

                if title == "" then title = url end

                local link  = string.format("[%s](%s)", title, url)
                local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                local line  = vim.api.nvim_get_current_line()
                -- insert after cursor position (like `p`)
                local new   = line:sub(1, col + 1) .. link .. line:sub(col + 2)
                vim.api.nvim_set_current_line(new)
                vim.api.nvim_win_set_cursor(0, { row, col + 1 + #link - 1 })
            end)
        end
    )
end

return M
