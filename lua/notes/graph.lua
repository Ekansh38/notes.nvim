-- Web-based graph view for notes.nvim.
-- Spawns a local Python HTTP server, generates graph JSON, opens browser.
-- Server stays alive for the Neovim session; browser can be reopened any time.

local M = {}

local PORT    = 7842
local _job_id = nil

-- Resolve the plugin root (notes.nvim/) from this file's path.
local function plugin_dir()
    local src = debug.getinfo(1, "S").source:sub(2)  -- strip leading "@"
    return vim.fn.fnamemodify(src, ":h:h:h")          -- graph.lua→notes→lua→root
end

-- Check if the server is already listening on PORT.
local function server_running()
    local result = vim.fn.system("lsof -ti:" .. PORT .. " 2>/dev/null")
    return vim.trim(result) ~= ""
end

-- Write graph JSON (with saved positions injected) to vault.
local function write_graph_json(cfg)
    local util = require("notes.util")
    local data = util.graph_data()

    -- Inject saved positions so nodes start where the user left them
    local pos_file = cfg.vault_path .. "/.notes-graph-positions.json"
    if vim.fn.filereadable(pos_file) == 1 then
        local raw = table.concat(vim.fn.readfile(pos_file), "")
        local ok, positions = pcall(vim.fn.json_decode, raw)
        if ok and type(positions) == "table" then
            for _, node in ipairs(data.nodes) do
                local p = positions[node.id]
                if p then
                    node.x = p.x
                    node.y = p.y
                end
            end
        end
    end

    local json_path = cfg.vault_path .. "/.notes-graph.json"
    vim.fn.writefile({ vim.fn.json_encode(data) }, json_path)
end

function M.open()
    local cfg = require("notes").config
    local dir = plugin_dir()

    local server_py = dir .. "/server/server.py"
    local html      = dir .. "/server/graph.html"

    -- Regenerate graph data every time so it's always fresh
    write_graph_json(cfg)

    if server_running() then
        -- Server already up — just (re)open the browser
        vim.fn.jobstart({ "open", "http://localhost:" .. PORT }, { detach = true })
        vim.notify("notes: graph refreshed → http://localhost:" .. PORT, vim.log.levels.INFO)
        return
    end

    -- Spawn the server
    _job_id = vim.fn.jobstart({
        "python3", server_py,
        "--socket", vim.v.servername,
        "--vault",  cfg.vault_path,
        "--port",   tostring(PORT),
        "--html",   html,
    }, {
        on_stderr = function(_, data)
            -- only surface real errors, not the startup line
            for _, line in ipairs(data or {}) do
                if line ~= "" and not line:match("notes graph server") then
                    vim.schedule(function()
                        vim.notify("notes graph: " .. line, vim.log.levels.WARN)
                    end)
                end
            end
        end,
    })

    if _job_id <= 0 then
        vim.notify("notes: failed to start graph server (is python3 available?)", vim.log.levels.ERROR)
        return
    end

    -- Give server ~400ms to bind, then open browser
    vim.defer_fn(function()
        vim.fn.jobstart({ "open", "http://localhost:" .. PORT }, { detach = true })
        vim.notify("notes: graph → http://localhost:" .. PORT, vim.log.levels.INFO)
    end, 400)
end

function M.stop()
    if _job_id and _job_id > 0 then
        vim.fn.jobstop(_job_id)
        _job_id = nil
        vim.notify("notes: graph server stopped", vim.log.levels.INFO)
    end
end

return M
