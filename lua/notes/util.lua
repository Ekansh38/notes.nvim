local M = {}

local _index = nil -- { ["Title or alias"] = "/full/path.md" }
local _ghost = nil -- { ["Linked but uncreated title"] = true }

-- Parse aliases from YAML frontmatter. Reads at most 30 lines.
-- Handles both forms:
--   aliases: [One, Two]
--   aliases:
--     - One
local function parse_aliases(path)
    local lines = vim.fn.readfile(path, "", 30)
    if not lines or #lines == 0 then return {} end
    if lines[1] ~= "---" then return {} end

    local aliases    = {}
    local in_aliases = false

    for i = 2, #lines do
        local line = lines[i]
        if line == "---" or line == "..." then break end

        local key, rest = line:match("^(%w+):%s*(.*)")
        if key == "aliases" then
            in_aliases = true
            local inline = rest:match("^%[(.-)%]")
            if inline then
                for alias in inline:gmatch("([^,]+)") do
                    alias = vim.trim(alias):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
                    if alias ~= "" then aliases[#aliases + 1] = alias end
                end
                in_aliases = false
            end
        elseif in_aliases then
            local alias = line:match("^%s*-%s+(.+)$")
            if alias then
                alias = vim.trim(alias):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
                if alias ~= "" then aliases[#aliases + 1] = alias end
            elseif line:match("^%S") then
                break
            end
        end
    end

    return aliases
end

-- Scan every file for [[links]]; anything linked but not yet a real file → ghost
local function scan_ghost_links()
    local cfg   = require("notes").config
    local files = vim.fn.glob(cfg.vault_path .. "/**/*.md", false, true)
    for _, path in ipairs(files) do
        local ok, lines = pcall(vim.fn.readfile, path)
        if ok then
            local content = table.concat(lines, "\n")
            for inner in content:gmatch("%[%[([^%]]+)%]%]") do
                local title = vim.trim(inner:match("^([^|]+)") or inner)
                if title ~= "" and not _index[title] then
                    _ghost[title] = true
                end
            end
        end
    end
end

local function build_index()
    local cfg   = require("notes").config
    _index = {}
    _ghost = {}
    local files = vim.fn.glob(cfg.vault_path .. "/**/*.md", false, true)
    for _, path in ipairs(files) do
        local title = vim.fn.fnamemodify(path, ":t:r")
        _index[title] = path
        for _, alias in ipairs(parse_aliases(path)) do
            if not _index[alias] then _index[alias] = path end
        end
    end
    scan_ghost_links()
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

-- Returns {title, exists} pairs for blink completion.
-- exists=true  → real file on disk
-- exists=false → linked in vault but file not created yet
function M.all_notes_for_completion()
    if not _index then build_index() end
    local results = {}
    for title in pairs(_index) do
        results[#results + 1] = { title = title, exists = true }
    end
    for title in pairs(_ghost) do
        results[#results + 1] = { title = title, exists = false }
    end
    return results
end

-- Legacy: still used by backlink.show and other places that only need titles
function M.all_titles()
    if not _index then build_index() end
    local titles = {}
    for title in pairs(_index) do titles[#titles + 1] = title end
    for title in pairs(_ghost) do titles[#titles + 1] = title end
    table.sort(titles)
    return titles
end

function M.invalidate()
    _index = nil
    _ghost = nil
end

return M
