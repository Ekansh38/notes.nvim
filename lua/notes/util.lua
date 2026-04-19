local M = {}

local _index = nil -- { ["Title or alias"] = "/full/path.md" }

-- Parse aliases from YAML frontmatter. Reads at most 30 lines.
-- Handles both block list and inline forms:
--   aliases: [Alias One, Alias Two]
--   aliases:
--     - Alias One
--     - Alias Two
local function parse_aliases(path)
    local lines = vim.fn.readfile(path, "", 30)
    if not lines or #lines == 0 then return {} end
    if lines[1] ~= "---" then return {} end  -- no frontmatter

    local aliases    = {}
    local in_aliases = false

    for i = 2, #lines do
        local line = lines[i]
        if line == "---" or line == "..." then break end -- end of frontmatter

        local key, rest = line:match("^(%w+):%s*(.*)")

        if key == "aliases" then
            in_aliases = true
            -- inline form: aliases: [One, Two]
            local inline = rest:match("^%[(.-)%]")
            if inline then
                for alias in inline:gmatch("([^,]+)") do
                    alias = vim.trim(alias):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
                    if alias ~= "" then aliases[#aliases + 1] = alias end
                end
                in_aliases = false -- fully consumed inline, don't enter block mode
            end
        elseif in_aliases then
            local alias = line:match("^%s*-%s+(.+)$")
            if alias then
                alias = vim.trim(alias):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
                if alias ~= "" then aliases[#aliases + 1] = alias end
            elseif line:match("^%S") then
                break -- new YAML key, aliases block is done
            end
        end
    end

    return aliases
end

local function build_index()
    local cfg = require("notes").config
    _index    = {}
    local files = vim.fn.glob(cfg.vault_path .. "/**/*.md", false, true)
    for _, path in ipairs(files) do
        local title = vim.fn.fnamemodify(path, ":t:r")
        _index[title] = path

        for _, alias in ipairs(parse_aliases(path)) do
            -- Don't clobber a real note title with an alias
            if not _index[alias] then
                _index[alias] = path
            end
        end
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

-- All titles AND aliases, sorted — fed to blink completion
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
