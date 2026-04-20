local M = {}

local _index            = nil  -- { [title_or_alias] = "/path.md" }
local _ghost            = nil  -- { [title] = true }
local _tags             = nil  -- { [tag] = { "/path.md", ... } }
local _has_backlinks    = nil  -- { ["/path.md"] = true }
local _backlink_counts  = nil  -- { ["/path.md"] = count }
local _pinned           = nil  -- { [title] = true }

-- ── frontmatter parser ────────────────────────────────────────────────────────
-- Reads aliases and tags from YAML frontmatter in a single pass over lines.
-- Both inline form (aliases: [A, B]) and list form (- A) are handled.
-- Returns: aliases table, tags table, index of last frontmatter line.

-- Returns aliases, tags, fm_end, pinned
local function parse_frontmatter(lines)
    local aliases    = {}
    local tags       = {}
    local pinned     = false
    local in_aliases = false
    local in_tags    = false
    local fm_end     = 0  -- index of closing ---; 0 means no frontmatter

    if not lines or #lines == 0 or lines[1] ~= "---" then
        return aliases, tags, fm_end, pinned
    end

    local function strip(v)
        return vim.trim(v):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
    end

    for i = 2, #lines do
        local line = lines[i]
        if line == "---" or line == "..." then
            fm_end = i
            break
        end

        local key, rest = line:match("^(%w+):%s*(.*)")
        if key then
            in_aliases = (key == "aliases")
            in_tags    = (key == "tags")
            if key == "pinned" and rest:match("^true") then pinned = true end
            local target = in_aliases and aliases or (in_tags and tags or nil)

            if target then
                local inline = rest:match("^%[(.-)%]")
                if inline then
                    for v in inline:gmatch("([^,]+)") do
                        v = strip(v):gsub("^#", "")
                        if v ~= "" then target[#target + 1] = v end
                    end
                    in_aliases = false
                    in_tags    = false
                end
            end
        elseif in_aliases or in_tags then
            local target = in_aliases and aliases or tags
            local v = line:match("^%s*-%s+(.+)$")
            if v then
                v = strip(v):gsub("^#", "")
                if v ~= "" then target[#target + 1] = v end
            elseif line:match("^%S") then
                in_aliases = false
                in_tags    = false
            end
        end
    end

    return aliases, tags, fm_end, pinned
end

-- Scan body lines (after frontmatter) for inline #tags.
-- Skips headings (lines starting with "# ").
-- Prepends a space to each line so "^#tag" and " #tag" share one pattern.

local function parse_inline_tags(lines, fm_end)
    local tags = {}
    local seen = {}
    for i = fm_end + 1, #lines do
        local line = lines[i]
        if not line:match("^#+%s") then
            for tag in (" " .. line):gmatch("%s#([%a][%w%-_/]*)") do
                if not seen[tag] then
                    seen[tag] = true
                    tags[#tags + 1] = tag
                end
            end
        end
    end
    return tags
end

-- ── index builder ─────────────────────────────────────────────────────────────
-- Two passes over vault files:
--   Pass 1 – build title→path index, alias→path index, tag→paths index.
--             Read each file exactly once and cache the lines.
--   Pass 2 – resolve [[wikilinks]] in each file:
--             known link  → mark target as having a backlink
--             unknown link → add to ghost set

local function build_index()
    local cfg = require("notes").config
    _index           = {}
    _ghost           = {}
    _tags            = {}
    _has_backlinks   = {}
    _backlink_counts = {}
    _pinned          = {}

    local files      = vim.fn.glob(cfg.vault_path .. "/**/*.md", false, true)
    local file_lines = {}  -- path → lines (reused in pass 2)

    -- Pass 1
    for _, path in ipairs(files) do
        local ok, lines = pcall(vim.fn.readfile, path)
        if not ok then goto continue end

        file_lines[path] = lines

        local title = vim.fn.fnamemodify(path, ":t:r")
        _index[title] = path

        local aliases, fm_tags, fm_end, is_pinned = parse_frontmatter(lines)

        if is_pinned then _pinned[title] = true end

        for _, alias in ipairs(aliases) do
            if not _index[alias] then _index[alias] = path end
        end

        local all_tags = fm_tags
        for _, t in ipairs(parse_inline_tags(lines, fm_end)) do
            all_tags[#all_tags + 1] = t
        end

        for _, tag in ipairs(all_tags) do
            if not _tags[tag] then _tags[tag] = {} end
            _tags[tag][#_tags[tag] + 1] = path
        end

        ::continue::
    end

    -- Pass 2
    for path, lines in pairs(file_lines) do
        local content = table.concat(lines, "\n")
        for inner in content:gmatch("%[%[([^%]]+)%]%]") do
            local linked = vim.trim(inner:match("^([^|]+)") or inner)
            if linked ~= "" then
                if _index[linked] then
                    local target = _index[linked]
                    _has_backlinks[target]  = true
                    _backlink_counts[target] = (_backlink_counts[target] or 0) + 1
                else
                    _ghost[linked] = true
                end
            end
        end
    end
end

-- ── public API ────────────────────────────────────────────────────────────────

-- Exact match first, case-insensitive fallback.
function M.find_note(title)
    if not _index then build_index() end
    if _index[title] then return _index[title] end
    local lower = title:lower()
    for k, v in pairs(_index) do
        if k:lower() == lower then return v end
    end
    return nil
end

-- { title, exists } pairs for [[wikilink]] blink completion.
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

-- Sorted title list (used by backlink and other callers).
function M.all_titles()
    if not _index then build_index() end
    local titles = {}
    for title in pairs(_index) do titles[#titles + 1] = title end
    for title in pairs(_ghost) do titles[#titles + 1] = title end
    table.sort(titles)
    return titles
end

-- { { tag, paths } } sorted alphabetically by tag — for tag search picker.
function M.all_tags()
    if not _index then build_index() end
    local result = {}
    for tag, paths in pairs(_tags) do
        result[#result + 1] = { tag = tag, paths = paths }
    end
    table.sort(result, function(a, b) return a.tag < b.tag end)
    return result
end

-- Tag names only — for blink completion.
function M.all_tag_names()
    if not _index then build_index() end
    local names = {}
    for tag in pairs(_tags) do names[#names + 1] = tag end
    return names
end

-- Paths of notes that have no inbound [[wikilinks]] from any other note.
function M.orphan_notes()
    if not _index then build_index() end
    local seen    = {}
    local orphans = {}
    for _, path in pairs(_index) do
        if not seen[path] then
            seen[path] = true
            if not _has_backlinks[path] then
                orphans[#orphans + 1] = path
            end
        end
    end
    table.sort(orphans)
    return orphans
end

-- { title, count } for the note with the most inbound wikilinks.
function M.most_linked()
    if not _index then build_index() end
    local best_path, best_count = nil, 0
    for path, count in pairs(_backlink_counts) do
        if count > best_count then
            best_path  = path
            best_count = count
        end
    end
    if not best_path then return nil end
    return { title = vim.fn.fnamemodify(best_path, ":t:r"), count = best_count }
end

-- { title, time } for the most recently modified vault note.
function M.last_modified()
    if not _index then build_index() end
    local best_path, best_time = nil, 0
    for _, path in pairs(_index) do
        local t = vim.fn.getftime(path)
        if t > best_time then
            best_time = t
            best_path = path
        end
    end
    if not best_path then return nil end
    return {
        title = vim.fn.fnamemodify(best_path, ":t:r"),
        time  = os.date("%Y-%m-%d %H:%M", best_time),
    }
end

-- Set of pinned note titles (title → true).
function M.pinned_set()
    if not _index then build_index() end
    return _pinned
end

function M.invalidate()
    _index           = nil
    _ghost           = nil
    _tags            = nil
    _has_backlinks   = nil
    _backlink_counts = nil
    _pinned          = nil
end

return M
