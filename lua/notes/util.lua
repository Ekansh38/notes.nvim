local M = {}

local _index = nil -- { ["Exact Title"] = "/full/path.md" }

local function build_index()
    local cfg = require("notes").config
    _index = {}
    local files = vim.fn.glob(cfg.vault_path .. "/**/*.md", false, true)
    for _, path in ipairs(files) do
        local title = vim.fn.fnamemodify(path, ":t:r")
        _index[title] = path
    end
end

-- Exact match first, case-insensitive fallback
function M.find_note(title)
    if not _index then build_index() end
    if _index[title] then return _index[title] end
    local lower = title:lower()
    for k, v in pairs(_index) do
        if k:lower() == lower then return v end
    end
    return nil
end

-- Returns all note titles (exact case), sorted
function M.all_titles()
    if not _index then build_index() end
    local titles = {}
    for title in pairs(_index) do
        titles[#titles + 1] = title
    end
    table.sort(titles)
    return titles
end

function M.invalidate()
    _index = nil
end

return M
