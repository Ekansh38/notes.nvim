local M = {}

-- Moment.js tokens → Lua date values.
-- Sorted longest-first so "MMMM" always wins over "MMM" over "MM" over "M".
-- Build token table given a timestamp (os.time() value or nil for now).
local function make_tokens(t)
    return {
        { "dddd", function() return os.date("%A",  t) end },
        { "ddd",  function() return os.date("%a",  t) end },
        { "MMMM", function() return os.date("%B",  t) end },
        { "MMM",  function() return os.date("%b",  t) end },
        { "YYYY", function() return os.date("%Y",  t) end },
        { "HH",   function() return os.date("%H",  t) end },
        { "DD",   function() return os.date("%d",  t) end },
        { "YY",   function() return os.date("%y",  t) end },
        { "MM",   function() return os.date("%m",  t) end },
        { "mm",   function() return os.date("%M",  t) end },
        { "ss",   function() return os.date("%S",  t) end },
        { "D",    function() return tostring(os.date("*t", t).day)   end },
        { "M",    function() return tostring(os.date("*t", t).month) end },
    }
end

local function format_moment(fmt, t)
    local tokens = make_tokens(t)
    table.sort(tokens, function(a, b) return #a[1] > #b[1] end)

    local replacements = {}
    local result = fmt

    -- Phase 1: replace each token with a unique control-character placeholder.
    -- Longest tokens are first so "MMMM" wins before "MM".
    for i, pair in ipairs(tokens) do
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

-- Parse a YYYY-MM-DD string into an os.time() timestamp, or nil.
local function title_to_timestamp(title)
    local y, m, d = title:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if y then
        return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d),
                         hour = 12, min = 0, sec = 0 })
    end
    return nil
end

-- Substitute all {{vars}} in content string given a note title.
-- If title is a YYYY-MM-DD date, date tokens use that date, not today.
function M.substitute(content, title)
    local t = title_to_timestamp(title)  -- nil means "use current time"
    -- {{date:format}} before {{date}} — more specific pattern wins
    content = content:gsub("{{date:([^}]+)}}", function(fmt)
        return format_moment(fmt, t)
    end)
    content = content:gsub("{{date}}", os.date("%Y-%m-%d", t))
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
