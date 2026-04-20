local M = {}

-- Moment.js tokens → Lua date values.
-- Sorted longest-first so "MMMM" always wins over "MMM" over "MM" over "M".
local TOKENS = {
    { "dddd", function() return os.date("%A") end },           -- "Sunday"
    { "ddd",  function() return os.date("%a") end },            -- "Sun"
    { "MMMM", function() return os.date("%B") end },           -- "April"
    { "MMM",  function() return os.date("%b") end },            -- "Apr"
    { "YYYY", function() return os.date("%Y") end },            -- "2026"
    { "HH",   function() return os.date("%H") end },            -- "14"
    { "DD",   function() return os.date("%d") end },            -- "18" (zero-padded)
    { "YY",   function() return os.date("%y") end },            -- "26"
    { "MM",   function() return os.date("%m") end },            -- "04"
    { "mm",   function() return os.date("%M") end },            -- "05" (minutes)
    { "ss",   function() return os.date("%S") end },            -- "00"
    { "D",    function() return tostring(os.date("*t").day) end },    -- "18" (no pad)
    { "M",    function() return tostring(os.date("*t").month) end },  -- "4"  (no pad)
}
table.sort(TOKENS, function(a, b) return #a[1] > #b[1] end)

local function format_moment(fmt)
    local replacements = {}
    local result = fmt

    -- Phase 1: replace each token with a unique control-character placeholder.
    -- Longest tokens are first (TOKENS is pre-sorted), so "MMMM" wins before "MM".
    -- Using \x01 as a delimiter — never appears in any date value — prevents
    -- "M" from matching the M in an already-substituted "Monday", etc.
    for i, pair in ipairs(TOKENS) do
        local ph  = string.format("\x01%02d\x01", i)
        local val = pair[2]()
        result = result:gsub(pair[1], function()
            replacements[ph] = val
            return ph
        end)
    end

    -- Phase 2: swap placeholders for actual values.
    for ph, val in pairs(replacements) do
        result = result:gsub(vim.pesc(ph), function() return val end)
    end

    return result
end

-- Substitute all {{vars}} in content string given a note title
function M.substitute(content, title)
    -- {{date:format}} before {{date}} — more specific pattern wins
    content = content:gsub("{{date:([^}]+)}}", function(fmt)
        return format_moment(fmt)
    end)
    content = content:gsub("{{date}}", os.date("%Y-%m-%d"))
    content = content:gsub("{{title}}", title)
    return content
end

-- Read a template file and apply substitutions. Returns content, err.
function M.load_and_apply(template_path, title)
    if vim.fn.filereadable(template_path) == 0 then
        return nil, "Template not found: " .. template_path
    end
    local lines = vim.fn.readfile(template_path)
    local content = table.concat(lines, "\n")
    return M.substitute(content, title), nil
end

return M
