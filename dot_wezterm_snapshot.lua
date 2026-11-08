-- Periodic pane/process snapshot for post-crash session recovery.
-- Appends deduplicated JSON to ~/.local/share/wezterm/snapshots.jsonl (12h retention).
-- Restore UI lives in ~/.local/bin/wezterm-restore.py.
--
-- Deliberately out of scope (KISS): scrollback text, pane geometry-perfect split
-- restoration, nvim/lazygit state, non-agent process relaunch.

local wezterm = require("wezterm")
local hash_utils = dofile(wezterm.config_dir .. "/.wezterm_hash.lua")

local HOME = wezterm.home_dir
local SNAPSHOT_DIR = HOME .. "/.local/share/wezterm"
local SNAPSHOT_PATH = SNAPSHOT_DIR .. "/snapshots.jsonl"
local INTERVAL_S = 120
local RETENTION_S = 12 * 60 * 60
local CODEX_SCAN_LIMIT = 60

local function sh(cmd)
    local handle = io.popen(cmd)
    if not handle then return "" end
    local out = handle:read("*a") or ""
    handle:close()
    return out
end

local function shellq(str) return "'" .. str:gsub("'", "'\\''") .. "'" end

local function trim(str) return (str:gsub("^%s*(.-)%s*$", "%1")) end

-- Lazily-built per-snapshot process tree, for locating agent state held by a
-- descendant (devin's acp child holds the session lock, not the TUI process)
local ppid_map, child_map
local function process_tree()
    if ppid_map then return end
    ppid_map, child_map = {}, {}
    for line in sh("ps -axo pid=,ppid="):gmatch("[^\n]+") do
        local pid, ppid = line:match("(%d+)%s+(%d+)")
        pid, ppid = tonumber(pid), tonumber(ppid)
        if pid then
            ppid_map[pid] = ppid
            child_map[ppid] = child_map[ppid] or {}
            child_map[ppid][#child_map[ppid] + 1] = pid
        end
    end
end

local function find_in_tree(pid, map)
    process_tree()
    local cur = pid
    while cur do
        if map[cur] then return map[cur] end
        cur = ppid_map[cur]
    end
    local queue, seen = { pid }, { [pid] = true }
    while #queue > 0 do
        local p = table.remove(queue, 1)
        if map[p] then return map[p] end
        for _, child in ipairs(child_map[p] or {}) do
            if not seen[child] then
                seen[child] = true
                queue[#queue + 1] = child
            end
        end
    end
    return nil
end

local devin_locks
local function devin_lock_map()
    if devin_locks then return devin_locks end
    devin_locks = {}
    local out = sh("lsof -F pn +d " .. shellq(HOME .. "/.local/share/devin/cli/session_locks") .. " 2>/dev/null")
    local pid
    for line in out:gmatch("[^\n]+") do
        local tag, val = line:sub(1, 1), line:sub(2)
        if tag == "p" then
            pid = tonumber(val)
        elseif tag == "n" and pid then
            devin_locks[pid] = val:match("([^/]+)%.lock$")
        end
    end
    return devin_locks
end

-- Session resolvers: each agent keeps session files on disk but none expose the id
-- in argv, so resolve from the live pid (exact) then fall back to cwd correlation
local session_resolvers = {
    -- A running claude writes sessions/<pid>.json with its live sessionId
    claude = function(cwd, pid)
        if pid then
            local f = io.open(HOME .. "/.claude/sessions/" .. pid .. ".json")
            if f then
                local id = f:read("*a"):match('"sessionId"%s*:%s*"([^"]+)"')
                f:close()
                if id then return id end
            end
        end
        local slug = cwd:gsub("[^%w]", "-")
        local newest =
            trim(sh("ls -t " .. shellq(HOME .. "/.claude/projects/" .. slug) .. "/*.jsonl 2>/dev/null | head -1"))
        if newest == "" then return nil end
        return newest:match("([^/]+)%.jsonl$")
    end,
    devin = function(cwd, pid)
        if pid then
            local id = find_in_tree(pid, devin_lock_map())
            if id then return id end
        end
        local db = HOME .. "/.local/share/devin/cli/sessions.db"
        local query = "SELECT id FROM sessions WHERE working_directory = '"
            .. cwd:gsub("'", "''")
            .. "' ORDER BY last_activity_at DESC LIMIT 1"
        local id = trim(sh("sqlite3 " .. shellq(db) .. " " .. shellq(query) .. " 2>/dev/null"))
        if id == "" then return nil end
        return id
    end,
    codex = function(cwd, _pid)
        -- Each rollout's first line is a session_meta record carrying the cwd;
        -- the resume id is the uuid tail of the rollout filename
        local needle = shellq('"cwd":"' .. cwd .. '"')
        local loop = "for f in $(ls -t "
            .. shellq(HOME .. "/.codex/sessions")
            .. "/*/*/*/rollout-*.jsonl 2>/dev/null | head -"
            .. CODEX_SCAN_LIMIT
            .. '); do head -1 "$f" | grep -Fq '
            .. needle
            .. ' && basename "$f" && break; done'
        local fname = trim(sh(loop))
        if fname == "" then return nil end
        return fname:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)")
    end,
}

local function detect_agent(executable, argv)
    local candidates = { executable }
    if argv and argv[1] then candidates[#candidates + 1] = argv[1] end
    for _, path in ipairs(candidates) do
        if path then
            for component in path:gmatch("[^/]+") do
                local lower = component:lower()
                if session_resolvers[lower] then return lower end
            end
        end
    end
    return nil
end

-- Last non-blank viewport line: best-effort capture of partially typed input.
-- For TUI apps this is status-bar chrome, and prompt glyphs cannot be separated
-- from typed text without OSC 133 zones — restore treats it as display context
local function capture_bottom_line(pane)
    local ok, text = pcall(function() return pane:get_lines_as_text(5) end)
    if not ok or not text then return nil end
    local last
    for line in text:gmatch("[^\n]+") do
        if line:match("%S") then last = line end
    end
    return last and trim(last) or nil
end

local function pane_snapshot(pane, info)
    local cwd_url = pane:get_current_working_dir()
    local cwd = cwd_url and cwd_url.file_path or ""
    local pinfo = pane:get_foreground_process_info() or {}
    local executable = pinfo.executable or pinfo.name or ""
    local agent = detect_agent(executable, pinfo.argv)

    local snap = {
        pane_id = pane:pane_id(),
        index = info.index,
        top = info.top,
        left = info.left,
        rows = info.height,
        cols = info.width,
        is_active = info.is_active,
        is_zoomed = info.is_zoomed,
        title = pane:get_title() or "",
        cwd = cwd,
        fg = {
            name = executable:match("([^/]+)$") or executable,
            pid = pinfo.pid,
            argv = pinfo.argv,
        },
        bottom_line = capture_bottom_line(pane),
    }
    if agent and cwd ~= "" then snap.session = { agent = agent, id = session_resolvers[agent](cwd, pinfo.pid) } end
    return snap
end

local function capture_tmux()
    local fmt =
        "#{session_name}|#{session_attached}|#{window_index}|#{window_name}|#{pane_index}|#{pane_current_command}|#{pane_current_path}"
    local out = sh("tmux list-panes -a -F " .. shellq(fmt) .. " 2>/dev/null")
    if trim(out) == "" then return nil end
    local panes = {}
    for line in out:gmatch("[^\n]+") do
        local fields = {}
        for f in line:gmatch("([^|]*)") do
            fields[#fields + 1] = f
        end
        panes[#panes + 1] = {
            session = fields[1],
            attached = fields[2] == "1",
            window_index = tonumber(fields[3]),
            window = fields[4],
            pane_index = tonumber(fields[5]),
            command = fields[6],
            cwd = fields[7],
        }
    end
    return panes
end

local last_signature

local function take_snapshot()
    local windows = {}
    local signature_parts = {}

    for _, mux_window in ipairs(wezterm.mux.all_windows()) do
        local window = {
            window_id = mux_window:window_id(),
            workspace = mux_window:get_workspace(),
            tabs = {},
        }
        for _, tab in ipairs(mux_window:tabs()) do
            local tab_snap = { tab_id = tab:tab_id(), title = tab:get_title() or "", panes = {} }
            for _, info in ipairs(tab:panes_with_info()) do
                local pane_ok, snap = pcall(pane_snapshot, info.pane, info)
                if pane_ok then
                    tab_snap.panes[#tab_snap.panes + 1] = snap
                    signature_parts[#signature_parts + 1] = wezterm.json_encode(snap)
                end
            end
            window.tabs[#window.tabs + 1] = tab_snap
        end
        windows[#windows + 1] = window
    end

    local tmux = capture_tmux()
    if #windows == 0 and not tmux then return end
    signature_parts[#signature_parts + 1] = wezterm.json_encode(tmux)
    local sig = hash_utils.hash_string(table.concat(signature_parts, "|"))
    if sig == last_signature then return end

    local now = os.time()

    -- Multiple wezterm-gui processes run this timer: dedupe reads the last
    -- retained on-disk line, and writes use tmp+rename to stay atomic.
    local keep = {}
    local cutoff = now - RETENTION_S
    local f = io.open(SNAPSHOT_PATH, "r")
    if f then
        for existing in f:lines() do
            local ts = tonumber(existing:match('"ts":(%d+)'))
            if ts and ts >= cutoff then
                keep[#keep + 1] = existing
                last_signature = tonumber(existing:match('"sig":(%d+)')) or last_signature
            end
        end
        f:close()
    end
    if sig == last_signature then return end
    last_signature = sig

    keep[#keep + 1] = wezterm.json_encode({
        v = 1,
        ts = now,
        iso = os.date("!%Y-%m-%dT%H:%M:%SZ", now),
        sig = sig,
        windows = windows,
        tmux = tmux,
    })
    -- Sig-named so equal writers share a path; differing writers can't tear it.
    local tmp = SNAPSHOT_PATH .. ".tmp." .. tostring(sig)
    f = io.open(tmp, "w")
    if not f then
        wezterm.log_error("snapshot: cannot write " .. tmp)
        return
    end
    f:write(table.concat(keep, "\n"), "\n")
    f:close()
    local ok, err = os.rename(tmp, SNAPSHOT_PATH)
    if not ok then wezterm.log_error("snapshot: rename failed: " .. tostring(err)) end
end

local function tick()
    local ok, err = pcall(take_snapshot)
    if not ok then wezterm.log_error("snapshot failed: " .. tostring(err)) end
    wezterm.time.call_after(INTERVAL_S, tick)
end

os.execute("mkdir -p " .. shellq(SNAPSHOT_DIR))
os.execute("rm -f " .. shellq(SNAPSHOT_DIR) .. "/snapshots.jsonl.tmp.*")
wezterm.time.call_after(5, tick)
