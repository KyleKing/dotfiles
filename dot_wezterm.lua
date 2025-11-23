-- Wezterm Docs: https://wezfurlong.org/wezterm/config/lua/general.html
--  Debug logs: `ls $HOME/.local/share/wezterm` (https://wezfurlong.org/wezterm/troubleshooting.html)

-- ============================================================================
-- Custom Keybindings (https://wezfurlong.org/wezterm/config/keys.html)
-- ============================================================================
--
-- WORKSPACE MANAGEMENT:
--  CMD+Shift+S - Switch workspace (fuzzy finder with zoxide integration)
--  CMD+Shift+N - Workspace note menu (view/edit/clear note)
--    CLI: wnote set "message" | wnote get | wnote edit | wnote clear
--
-- TAB MANAGEMENT:
--  CMD+N - New window
--  CMD+T - New tab
--  CMD+W - Close current tab (with confirmation)
--  CMD+1-9 - Jump to tab number
--  CMD+ALT+Left/Right - Switch to previous/next tab
--  CMD+CTRL+Left/Right (or H/L) - Move tab left/right
--  CMD+Shift+O - Auto-organize tabs by git directory
--  CMD+R - Reload configuration file
--
-- PANE MANAGEMENT (with Neovim integration):
--  CMD+D - Split pane horizontally (left/right)
--  CMD+Shift+D - Split pane vertically (top/bottom)
--  CTRL+H/J/K/L - Navigate panes/nvim splits (seamlessly with smart-splits.nvim)
--  ALT+Arrow - Resize panes/nvim splits (seamlessly with smart-splits.nvim)
--  CMD+[ or ] - Cycle through panes (prev/next)
--  CMD+Shift+Arrow - Navigate to pane in direction
--  CMD+Shift+Alt+Arrow - Resize pane in direction
--  CMD+Shift+W - Close current pane (with confirmation)
--  CMD+Z - Toggle pane zoom (maximize/restore current pane)
--
-- NAVIGATION & EDITING:
--  ALT+Left/Right - Jump backward/forward by word
--  CMD+Left/Right - Jump to start/end of line (standard: C-a, C-e)
--  CTRL+B/F - Scroll page up/down (vim-style)
--  CMD+Up - Jump to previous prompt (requires shell integration)
--  CMD+Shift+Down - Jump to next prompt (requires shell integration)
--  CMD+Down - Scroll to bottom
--
-- TEXT SELECTION & SEARCH:
--  CMD+Space - Quick select (highlights URLs, paths, hashes, IPs for quick copy)
--  CMD+O - Quick select and open URLs
--  CMD+F - Search scrollback (Enter/Ctrl-N/P to navigate matches, Ctrl-U to clear)
--  CMD+X - Enter copy mode (vim-style navigation)
--  Copy Mode (https://wezfurlong.org/wezterm/copymode.html):
--   hjkl - Vim movement, w/b/e - Word navigation, 0/$/^ - Line navigation
--   H/M/L - Move to top/middle/bottom of viewport
--   gg/G - Jump to top/bottom of scrollback
--   Ctrl-D/U - Half page down/up, Ctrl-F/B - Full page down/up
--   / - Search, n/N - Next/previous match
--   v/V/Ctrl-V - Visual select (char/line/block)
--   y/Enter - Copy and exit, q/Escape - Exit without copying
--
-- SCROLLBACK MANAGEMENT:
--  CMD+K then C-l - Clear scrollback (or type 'clear')
--
-- MOUSE:
--  CTRL+Click - Open link under cursor
--
-- Resources:
--  Example configs: https://github.com/wez/wezterm/discussions/628
--  Pane splitting: https://wezfurlong.org/wezterm/config/lua/keyassignment/SplitPane.html
--
-- ============================================================================
-- Shell Integration Setup (Required for prompt jumping and command tracking)
-- ============================================================================
-- Add to your shell config file (.zshrc, .bashrc, etc.):
--
-- For Zsh (~/.zshrc):
--   eval "$(wezterm shell-integration --shell zsh)"
--
-- For Bash (~/.bashrc):
--   eval "$(wezterm shell-integration --shell bash)"
--
-- For Fish (~/.config/fish/config.fish):
--   wezterm shell-integration --shell fish | source
--
-- This enables:
-- - Prompt jumping (CMD+Up/Down to jump between commands)
-- - Command tracking in status bar
-- - Error detection (shows alert icon when command fails)
-- - Semantic zones for better text selection
--
-- Docs: https://wezfurlong.org/wezterm/shell-integration.html
-- ============================================================================

local wezterm = require("wezterm")

-- ============================================================================
-- Plugin: Zoxide Workspace Switcher
-- ============================================================================
-- Smart workspace switching with fuzzy finding and zoxide integration
-- Allows quick project switching based on zoxide's directory frequency/recency
local workspace_switcher = wezterm.plugin.require(
    "https://github.com/MLFlexer/smart_workspace_switcher.wezterm"
)

-- Configure zoxide path (adjust if needed for your system)
workspace_switcher.zoxide_path = "/opt/homebrew/bin/zoxide"

-- Optional: Filter to specific directories (uncomment and modify as needed)
-- workspace_switcher.workspace_dirs = {
--     wezterm.home_dir .. "/Developer",
--     wezterm.home_dir .. "/Projects",
-- }

-- ============================================================================
-- Plugin: Smart Splits (Neovim Integration)
-- ============================================================================
-- Seamless navigation between Neovim splits and WezTerm panes
-- Requires smart-splits.nvim plugin in Neovim
-- Install in Neovim: https://github.com/mrjones2014/smart-splits.nvim
--
-- Neovim setup (add to your init.lua):
--   require('smart-splits').setup()
--   vim.keymap.set('n', '<C-h>', require('smart-splits').move_cursor_left)
--   vim.keymap.set('n', '<C-j>', require('smart-splits').move_cursor_down)
--   vim.keymap.set('n', '<C-k>', require('smart-splits').move_cursor_up)
--   vim.keymap.set('n', '<C-l>', require('smart-splits').move_cursor_right)
local smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")

-- ============================================================================
-- Configuration for Tab Color

-- Based on: https://github.com/protiumx/.dotfiles/blob/854d4b159a0a0512dc24cbc840af467ac84085f8/stow/wezterm/.config/wezterm/wezterm.lua#L291-L319
-- Icons from: https://www.nerdfonts.com/cheat-sheet
local process_icons = {
    ["bash"] = wezterm.nerdfonts.md_bash,
    ["btm"] = wezterm.nerdfonts.mdi_chart_donut_variant,
    ["cargo"] = wezterm.nerdfonts.dev_rust,
    ["curl"] = wezterm.nerdfonts.mdi_flattr,
    ["deno"] = wezterm.nerdfonts.md_dinosaur,
    ["docker"] = wezterm.nerdfonts.md_docker,
    ["docker-compose"] = wezterm.nerdfonts.md_docker,
    ["gh"] = wezterm.nerdfonts.dev_github_badge,
    ["git"] = wezterm.nerdfonts.fa_git,
    ["go"] = wezterm.nerdfonts.seti_go,
    ["htop"] = wezterm.nerdfonts.mdi_chart_donut_variant,
    ["kubectl"] = wezterm.nerdfonts.md_kubernetes,
    ["lazydocker"] = wezterm.nerdfonts.md_docker,
    ["lazygit"] = wezterm.nerdfonts.dev_git_branch,
    ["lua"] = wezterm.nerdfonts.seti_lua,
    ["make"] = wezterm.nerdfonts.seti_makefile,
    ["mise"] = wezterm.nerdfonts.md_carrot,
    ["node"] = wezterm.nerdfonts.cod_json,
    ["npm"] = wezterm.nerdfonts.md_npm,
    ["nvim"] = wezterm.nerdfonts.linux_neovim,
    ["pnpm"] = wezterm.nerdfonts.md_package_variant,
    ["psql"] = wezterm.nerdfonts.md_database,
    ["python"] = wezterm.nerdfonts.dev_python,
    ["python3"] = wezterm.nerdfonts.dev_python,
    ["rg"] = wezterm.nerdfonts.md_magnify,
    ["ruby"] = wezterm.nerdfonts.cod_ruby,
    ["rust"] = wezterm.nerdfonts.dev_rust,
    ["ssh"] = wezterm.nerdfonts.md_server_network,
    ["sudo"] = wezterm.nerdfonts.fa_hashtag,
    ["terraform"] = wezterm.nerdfonts.md_terraform,
    ["top"] = wezterm.nerdfonts.mdi_chart_donut_variant,
    ["usql"] = wezterm.nerdfonts.md_database,
    ["vim"] = wezterm.nerdfonts.dev_vim,
    ["wget"] = wezterm.nerdfonts.mdi_arrow_down_box,
    ["yarn"] = wezterm.nerdfonts.md_nodejs,
    ["zsh"] = wezterm.nerdfonts.cod_terminal_bash,
}

local icon_active = wezterm.nerdfonts.md_rocket_launch
local icon_unseen = wezterm.nerdfonts.cod_eye
local icon_git_root = "./"
local icon_not_git = wezterm.nerdfonts.md_map_marker_radius

-- Non-breaking space to prevent Wezterm from collapsing consecutive spaces
local nbsp = "\u{00A0}"

-- Git lookup cache to avoid repeated expensive io.popen calls
local git_cache = {}
local GIT_CACHE_TTL = 600 -- 10 minutes

local function get_cached_git_root(cwd)
    local now = os.time()
    local cached = git_cache[cwd]

    if cached and (now - cached.timestamp) < GIT_CACHE_TTL then
        return cached.root, cached.is_git_repo, cached.depth_indicator
    end

    local git_root = ""
    local is_git_repo = false
    local depth_indicator = icon_not_git

    local handle = io.popen("cd '" .. cwd .. "' 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null")
    if handle then
        git_root = handle:read("*a"):gsub("%s+$", "")
        handle:close()
        if git_root ~= "" then
            is_git_repo = true

            -- At git root
            if cwd == git_root then
                depth_indicator = icon_git_root
            else
                -- Calculate depth indicator while we have the git root
                local relative_path = cwd:gsub("^" .. git_root:gsub("([^%w])", "%%%1") .. "/?", "")
                local depth = 0
                for _ in relative_path:gmatch("/") do
                    depth = depth + 1
                end
                depth = depth + 1

                local current_dir = cwd:match("([^/]+)$") or ""
                local prefix = current_dir:sub(1, 2):lower()
                depth_indicator = string.format("%d%s", depth, prefix)
            end
        end
    end

    git_cache[cwd] = {
        root = git_root,
        is_git_repo = is_git_repo,
        depth_indicator = depth_indicator,
        timestamp = now,
    }

    for key, value in pairs(git_cache) do
        if (now - value.timestamp) >= GIT_CACHE_TTL * 2 then git_cache[key] = nil end
    end

    return git_root, is_git_repo, depth_indicator
end

-- Return the Tab's current working directory
local function get_cwd(tab)
    -- Note, returns URL Object: https://wezfurlong.org/wezterm/config/lua/pane/get_current_working_dir.html
    return tab.active_pane.current_working_dir.file_path or ""
end

-- Remove all path components and return only the last value
local function remove_abs_path(path) return path:gsub("(.*[/\\])(.*)", "%2") end

-- Calculate depth from git root and create indicator (uses cached value)
local function get_git_depth_indicator(tab)
    local cwd = get_cwd(tab):gsub("^file://", "")
    local _, _, depth_indicator = get_cached_git_root(cwd)
    return depth_indicator
end

-- Get the git root directory name, or fallback to current directory name
local function get_git_dir_name(tab)
    local cwd = get_cwd(tab):gsub("^file://", "")
    local git_root, is_git_repo, _ = get_cached_git_root(cwd)
    if is_git_repo then return remove_abs_path(git_root) end
    return "./" .. remove_abs_path(cwd)
end

-- Return the concise name or icon of the running process for display
local function get_process(tab)
    if not tab.active_pane or tab.active_pane.foreground_process_name == "" then return "[?]" end

    local process_name = remove_abs_path(tab.active_pane.foreground_process_name)

    return process_icons[process_name] or string.format("[%s]", process_name)
end

-- Format the main content of the tab
local function format_tab_content(tab, has_unseen)
    local dir_name = get_git_dir_name(tab)
    local depth_indicator = get_git_depth_indicator(tab)
    local process = get_process(tab)
    local unseen_indicator = has_unseen and icon_unseen or ""

    -- Build content with consistent spacing
    local parts = {}
    if unseen_indicator ~= "" then table.insert(parts, unseen_indicator) end
    table.insert(parts, process)
    table.insert(parts, dir_name)
    table.insert(parts, depth_indicator)

    return table.concat(parts, " ")
end

-- Helper to add a segment to the format table
local function add_segment(format, bg_color, fg_color, text, bold)
    table.insert(format, { Background = { Color = bg_color } })
    table.insert(format, { Foreground = { Color = fg_color } })
    if bold then table.insert(format, { Attribute = { Intensity = "Bold" } }) end
    table.insert(format, { Text = text })
end

-- Track which tabs have been visited to work around buggy has_unseen_output
local visited_tabs = {}

-- Determine if a tab has unseen output since last visited
local function has_unseen_output(tab)
    local tab_id = tab.tab_id

    -- If tab is currently active, mark it as visited
    if tab.is_active then
        visited_tabs[tab_id] = true
        return false
    end

    -- For inactive tabs, check if we've visited them before
    if visited_tabs[tab_id] then
        return false -- Already visited, no indicator
    end

    -- Not visited yet, check if there's unseen output
    for _, pane in ipairs(tab.panes) do
        if pane.has_unseen_output then return true end
    end

    return false
end

-- Convert arbitrary strings to a unique hex color value
-- Based on: https://stackoverflow.com/a/3426956/3219667
local function string_to_color(str)
    -- Convert the string to a unique integer
    local hash = 0
    for i = 1, #str do
        -- Bitwise Left Shift: (hash << 5) is equivalent to hash * 32
        hash = string.byte(str, i) + (hash * 32 - hash)
    end
    -- Convert the integer to a unique color (mask to 24 bits)
    -- Bitwise AND with 0x00FFFFFF is equivalent to modulo 0x01000000
    local c = string.format("%06X", math.abs(hash) % 0x01000000)
    return "#" .. (string.rep("0", 6 - #c) .. c):upper()
end

local function select_contrasting_fg_color(hex_color)
    local color = wezterm.color.parse(hex_color)
    ---@diagnostic disable-next-line: unused-local
    local lightness, _a, _b, _alpha = color:laba()
    if lightness > 55 then
        return "#000000" -- Black has higher contrast with colors perceived to be "bright"
    end
    return "#FFFFFF" -- White has higher contrast
end

-- Inline tests
local testColor = string_to_color("/Users/kyleking/Developer/ProjectA")
assert(testColor == "#EBD168", "Unexpected color value for test hash (" .. testColor .. ")")
assert(select_contrasting_fg_color("#494CED") == "#FFFFFF", "Expected higher contrast with white")
assert(select_contrasting_fg_color("#128b26") == "#FFFFFF", "Expected higher contrast with white")
assert(select_contrasting_fg_color("#58f5a6") == "#000000", "Expected higher contrast with black")
assert(select_contrasting_fg_color("#EBD168") == "#000000", "Expected higher contrast with black")

-- Get full git root path for color hashing (not just the name)
local function get_git_root_path(tab)
    local cwd = get_cwd(tab):gsub("^file://", "")
    local git_root, is_git_repo, _ = get_cached_git_root(cwd)
    if is_git_repo then return git_root end
    return cwd
end

-- Helper function to dim colors for inactive tabs
local function dim_color(hex_color, factor)
    local color = wezterm.color.parse(hex_color)
    local h, s, l, a = color:hsla()
    -- Reduce lightness for inactive tabs to make them more subtle
    l = l * factor
    local dimmed = wezterm.color.from_hsla(h, s, l, a)
    -- Convert back to hex string format
    local r, g, b, _ = dimmed:srgba_u8()
    return string.format("#%02X%02X%02X", r, g, b)
end

-- On format tab title events, override the default handling to return a custom title
-- Docs: https://wezfurlong.org/wezterm/config/lua/window-events/format-tab-title.html
---@diagnostic disable-next-line: unused-local
wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, _hover, _max_width)
    local has_unseen = has_unseen_output(tab)
    local base_color = string_to_color(get_git_root_path(tab))

    -- Handle custom titles
    if tab.tab_title and #tab.tab_title > 0 then
        local bg_color = tab.is_active and "#FFFFFF" or dim_color(base_color, 0.7)
        local fg_color = select_contrasting_fg_color(bg_color)
        local format = {}
        local padding = tab.is_active and (nbsp .. nbsp) or nbsp
        add_segment(format, bg_color, fg_color, padding .. tab.tab_title .. padding, tab.is_active)
        return format
    end

    local content = format_tab_content(tab, has_unseen)
    local format = {}

    if tab.is_active then
        -- Active tab: clean white background with colored accent on left
        local white_bg = "#FFFFFF"
        local accent_bg = base_color
        local accent_fg = select_contrasting_fg_color(accent_bg)

        add_segment(format, accent_bg, accent_fg, " " .. icon_active, true)
        add_segment(format, white_bg, "#000000", " " .. content .. " ", true)
    else
        -- Inactive tab: dimmed color with subtle padding
        local bg_color = dim_color(base_color, 0.6)
        local fg_color = select_contrasting_fg_color(bg_color)
        add_segment(format, bg_color, fg_color, nbsp .. content .. nbsp, false)
    end

    return format
end)

-- ============================================================================
-- General configuration

local config = wezterm.config_builder()

-- Apply smart-splits integration (must be done before defining keys)
-- This enables seamless navigation between Neovim and WezTerm panes
smart_splits.apply_to_config(config, {
    direction_keys = {
        move = { "h", "j", "k", "l" },
        resize = { "LeftArrow", "DownArrow", "UpArrow", "RightArrow" },
    },
    modifiers = {
        move = "CTRL",
        resize = "META", -- ALT key
    },
})

-- Font & Text
config.font_size = 13.5
config.bold_brightens_ansi_colors = true
config.line_height = 1.0

-- Window & Terminal
config.initial_cols = 200
config.initial_rows = 60
config.scrollback_lines = 50000 -- Increased for long build outputs
config.enable_scroll_bar = false
config.adjust_window_size_when_changing_font_size = false

-- Performance
config.animation_fps = 60
config.max_fps = 60
config.front_end = "WebGpu" -- Options: OpenGL, WebGpu, Software

-- Shell integration for better prompts and command tracking
config.enable_kitty_graphics = true

-- ============================================================================
-- Quick Select Patterns (for fast URL/path/hash selection)
-- ============================================================================
config.quick_select_patterns = {
    -- Git commit hashes (7-40 characters)
    "\\b[0-9a-f]{7,40}\\b",
    -- UUIDs
    "\\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\b",
    -- Issue tracker references (JIRA-style)
    "\\b[A-Z]{2,}-\\d+\\b",
    -- Kubernetes resource names
    "\\b[a-z0-9]([-a-z0-9]*[a-z0-9])?\\b",
    -- IP addresses (already in defaults but explicit here)
    "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b",
    -- File paths with common extensions
    "[\\w\\-\\.\\/]+\\.(py|js|ts|lua|rs|go|md|json|yaml|yml|toml|txt)\\b",
}

-- Quick select alphabet (default but can be customized for easier finger positions)
config.quick_select_alphabet = "asdfghjklqwertyuiopzxcvbnm"

local act = wezterm.action
config.keys = {
    -- Workspace management (zoxide integration)
    { key = "s", mods = "CMD|SHIFT", action = workspace_switcher.switch_workspace() },

    -- Tab management
    { key = "w", mods = "CMD", action = act.CloseCurrentTab({ confirm = true }) },
    { key = "LeftArrow", mods = "CMD|ALT", action = act.ActivateTabRelative(-1) },
    { key = "RightArrow", mods = "CMD|ALT", action = act.ActivateTabRelative(1) },

    -- Pane splitting and navigation
    { key = "d", mods = "CMD", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "d", mods = "CMD|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "[", mods = "CMD", action = act.ActivatePaneDirection("Prev") },
    { key = "]", mods = "CMD", action = act.ActivatePaneDirection("Next") },
    { key = "LeftArrow", mods = "CMD|SHIFT", action = act.ActivatePaneDirection("Left") },
    { key = "RightArrow", mods = "CMD|SHIFT", action = act.ActivatePaneDirection("Right") },
    { key = "UpArrow", mods = "CMD|SHIFT", action = act.ActivatePaneDirection("Up") },
    { key = "DownArrow", mods = "CMD|SHIFT", action = act.ActivatePaneDirection("Down") },
    { key = "w", mods = "CMD|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
    { key = "z", mods = "CMD", action = act.TogglePaneZoomState },

    -- Pane resizing
    { key = "LeftArrow", mods = "CMD|ALT|SHIFT", action = act.AdjustPaneSize({ "Left", 5 }) },
    { key = "RightArrow", mods = "CMD|ALT|SHIFT", action = act.AdjustPaneSize({ "Right", 5 }) },
    { key = "UpArrow", mods = "CMD|ALT|SHIFT", action = act.AdjustPaneSize({ "Up", 5 }) },
    { key = "DownArrow", mods = "CMD|ALT|SHIFT", action = act.AdjustPaneSize({ "Down", 5 }) },

    -- Word jumping (standard Mac behavior)
    { key = "LeftArrow", mods = "ALT", action = act.SendString("\x1bb") },
    { key = "RightArrow", mods = "ALT", action = act.SendString("\x1bf") },

    -- Vim-friendly scrolling
    { key = "b", mods = "CTRL", action = act.ScrollByPage(-0.9) },
    { key = "f", mods = "CTRL", action = act.ScrollByPage(0.9) },
    { key = "DownArrow", mods = "CMD", action = act.ScrollToBottom },

    -- Prompt jumping (requires shell integration)
    { key = "UpArrow", mods = "CMD", action = act.ScrollToPrompt(-1) },
    { key = "DownArrow", mods = "CMD|SHIFT", action = act.ScrollToPrompt(1) },

    -- Enhanced text navigation
    { key = "x", mods = "CMD", action = act.ActivateCopyMode },
    { key = "f", mods = "CMD", action = act.Search({ CaseInSensitiveString = "" }) },

    -- Quick select (URLs, paths, hashes, etc.)
    { key = "Space", mods = "CMD", action = act.QuickSelect },
    {
        key = "o",
        mods = "CMD",
        action = act.QuickSelectArgs({
            label = "open url",
            patterns = { "https?://\\S+" },
            action = wezterm.action_callback(function(window, pane)
                local url = window:get_selection_text_for_pane(pane)
                wezterm.open_with(url)
            end),
        }),
    },

    -- Tab reordering
    { key = "LeftArrow", mods = "CMD|CTRL", action = act.MoveTabRelative(-1) },
    { key = "RightArrow", mods = "CMD|CTRL", action = act.MoveTabRelative(1) },
    { key = "h", mods = "CMD|CTRL", action = act.MoveTabRelative(-1) },
    { key = "l", mods = "CMD|CTRL", action = act.MoveTabRelative(1) },

    -- Auto-organize tabs by git directory
    {
        key = "o",
        mods = "CMD|SHIFT",
        action = wezterm.action_callback(function(window, pane)
            local mux_window = window:mux_window()
            local tabs = mux_window:tabs_with_info()

            -- Build tab info with git roots
            local tab_info = {}
            for _, tab_item in ipairs(tabs) do
                local tab = tab_item.tab
                local cwd = ""
                if tab:active_pane() and tab:active_pane():get_current_working_dir() then
                    cwd = tab:active_pane():get_current_working_dir().file_path or ""
                end

                local git_root, _, _ = get_cached_git_root(cwd)
                table.insert(tab_info, {
                    tab = tab,
                    git_root = git_root,
                    cwd = cwd,
                    index = tab_item.index,
                })
            end

            -- Sort by git root, then by cwd
            table.sort(tab_info, function(a, b)
                if a.git_root ~= b.git_root then
                    -- Sort by git root (non-git repos at end)
                    if a.git_root == "" then
                        return false
                    elseif b.git_root == "" then
                        return true
                    else
                        return a.git_root < b.git_root
                    end
                else
                    -- Within same repo, sort by cwd
                    return a.cwd < b.cwd
                end
            end)

            -- Reorder tabs
            for new_index, info in ipairs(tab_info) do
                local old_index = info.index
                if old_index ~= new_index - 1 then
                    info.tab:set_active()
                    -- Move tab to new position
                    for i = old_index, new_index - 2, -1 do
                        window:perform_action(act.MoveTabRelative(-1), pane)
                    end
                    for i = old_index, new_index, 1 do
                        window:perform_action(act.MoveTabRelative(1), pane)
                    end
                end
            end
        end),
    },

    -- Workspace notes management
    {
        key = "n",
        mods = "CMD|SHIFT",
        action = wezterm.action_callback(function(window, pane)
            local workspace = window:active_workspace()

            -- Read current note
            local notes_dir = os.getenv("HOME") .. "/.local/share/wezterm/workspace-notes"
            local note_file = notes_dir .. "/" .. workspace .. ".txt"
            local current_note = "[No note set]"

            local file = io.open(note_file, "r")
            if file then
                current_note = file:read("*all"):gsub("^%s*(.-)%s*$", "%1")
                file:close()
            end

            -- Show menu
            window:perform_action(
                act.InputSelector({
                    title = "Workspace Note: " .. workspace,
                    choices = {
                        { id = "view", label = "📄 " .. current_note },
                        { id = "set", label = "✏️  Quick set note" },
                        { id = "edit", label = "📝 Edit in $EDITOR" },
                        { id = "clear", label = "🗑️  Clear note" },
                        { id = "list", label = "📋 List all notes" },
                    },
                    fuzzy = false,
                    action = wezterm.action_callback(function(win, pane, id, label)
                        if id == "set" then
                            win:perform_action(
                                act.PromptInputLine({
                                    description = "Enter note for " .. workspace .. ":",
                                    action = wezterm.action_callback(function(win, pane, line)
                                        if line and line ~= "" then
                                            pane:send_text("wnote set \"" .. line .. "\"\n")
                                        end
                                    end),
                                }),
                                pane
                            )
                        elseif id == "edit" then
                            pane:send_text("wnote edit\n")
                        elseif id == "clear" then
                            pane:send_text("wnote clear\n")
                        elseif id == "list" then
                            pane:send_text("wnote list\n")
                        end
                    end),
                }),
                pane
            )
        end),
    },
}

-- ============================================================================
-- Enhanced Copy Mode (Vim-style navigation for scrollback)
-- ============================================================================
config.key_tables = {
    copy_mode = {
        -- Vim-style movement
        { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
        { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
        { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
        { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },

        -- Word navigation
        { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
        { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
        { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },

        -- Line navigation
        { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
        { key = "$", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
        { key = "^", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },

        -- Viewport navigation
        { key = "H", mods = "SHIFT", action = act.CopyMode("MoveToViewportTop") },
        { key = "M", mods = "SHIFT", action = act.CopyMode("MoveToViewportMiddle") },
        { key = "L", mods = "SHIFT", action = act.CopyMode("MoveToViewportBottom") },

        -- Scrollback navigation
        { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
        { key = "G", mods = "SHIFT", action = act.CopyMode("MoveToScrollbackBottom") },
        { key = "d", mods = "CTRL", action = act.CopyMode("MoveByPage(0.5)") },
        { key = "u", mods = "CTRL", action = act.CopyMode("MoveByPage(-0.5)") },
        { key = "f", mods = "CTRL", action = act.CopyMode("PageDown") },
        { key = "b", mods = "CTRL", action = act.CopyMode("PageUp") },

        -- Search
        { key = "/", mods = "NONE", action = act.Search("CurrentSelectionOrEmptyString") },
        { key = "n", mods = "NONE", action = act.CopyMode("NextMatch") },
        { key = "N", mods = "SHIFT", action = act.CopyMode("PriorMatch") },

        -- Visual selection modes
        { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
        { key = "V", mods = "SHIFT", action = act.CopyMode({ SetSelectionMode = "Line" }) },
        {
            key = "v",
            mods = "CTRL",
            action = act.CopyMode({ SetSelectionMode = "Block" }),
        },

        -- Copy and exit
        {
            key = "y",
            mods = "NONE",
            action = act.Multiple({
                { CopyTo = "ClipboardAndPrimarySelection" },
                { CopyMode = "Close" },
            }),
        },
        {
            key = "Enter",
            mods = "NONE",
            action = act.Multiple({
                { CopyTo = "ClipboardAndPrimarySelection" },
                { CopyMode = "Close" },
            }),
        },

        -- Exit copy mode
        { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
        { key = "q", mods = "NONE", action = act.CopyMode("Close") },
        { key = "c", mods = "CTRL", action = act.CopyMode("Close") },
    },

    search_mode = {
        -- Navigate between search matches
        { key = "Enter", mods = "NONE", action = act.CopyMode("NextMatch") },
        { key = "n", mods = "CTRL", action = act.CopyMode("NextMatch") },
        { key = "p", mods = "CTRL", action = act.CopyMode("PriorMatch") },
        { key = "u", mods = "CTRL", action = act.CopyMode("ClearPattern") },
        { key = "r", mods = "CTRL", action = act.CopyMode("CycleMatchType") },

        -- Exit search mode
        { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
    },
}

config.mouse_bindings = {
    -- Ctrl-click will open the link under the mouse cursor
    {
        event = { Up = { streak = 1, button = "Left" } },
        mods = "CTRL",
        action = wezterm.action.OpenLinkAtMouseCursor,
    },
}

-- Brew install fonts and verify installation and name in Apple's "Font Book"
config.font = wezterm.font_with_fallback({
    -- "Atkinson Hyperlegible Mono",
    "FiraCode Nerd Font Mono",
    "FiraMono Nerd Font Mono",
    "Hack Nerd Font Mono",
    "Fira Code",
})

-- Colors & Appearance
-- Docs: https://wezfurlong.org/wezterm/config/appearance.html
config.color_scheme = "Catppuccin Frappe"

-- Stylize the Window
config.window_decorations = "RESIZE"
config.use_fancy_tab_bar = false -- Use retro tab bar for full color control
config.tab_max_width = 64 -- Increase from default 16 to prevent clipping of tab titles
config.hide_tab_bar_if_only_one_tab = true
config.show_tab_index_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false

-- Maximize space used by nvim
config.window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
}

-- ============================================================================
-- Status Bar (with command tracking and git integration)
-- ============================================================================

-- Track command counts per pane
local command_counts = {}

-- Event: Track command execution (requires shell integration)
wezterm.on("update-status", function(window, pane)
    local pane_id = pane:pane_id()

    -- Initialize command count for this pane if not exists
    if not command_counts[pane_id] then command_counts[pane_id] = 0 end

    -- Increment on new command (when user_vars.WEZTERM_PROG changes)
    local user_vars = pane:get_user_vars()
    if user_vars.WEZTERM_PROG and user_vars.WEZTERM_PROG ~= "" then
        command_counts[pane_id] = command_counts[pane_id] + 1
    end
end)

-- Event: Update right status bar
wezterm.on("update-right-status", function(window, pane)
    local workspace = window:active_workspace()
    local cwd_uri = pane:get_current_working_dir()
    local date = wezterm.strftime("%H:%M")

    -- Get git branch if in a git repo
    local git_branch = ""
    if cwd_uri then
        local cwd = cwd_uri.file_path
        local success, stdout, stderr = wezterm.run_child_process({
            "git",
            "-C",
            cwd,
            "branch",
            "--show-current",
        })
        if success and stdout ~= "" then
            git_branch = " " .. wezterm.nerdfonts.dev_git_branch .. " " .. stdout:gsub("\n", "")
        end
    end

    -- Get command count for current pane
    local pane_id = pane:pane_id()
    local cmd_count = command_counts[pane_id] or 0

    -- Check for errors (exit status from last command)
    local exit_status = pane:get_user_vars().WEZTERM_EXIT_STATUS or "0"
    local error_indicator = ""
    if exit_status ~= "0" then
        error_indicator = " " .. wezterm.nerdfonts.md_alert_circle .. " "
    end

    -- Check if pane is zoomed
    local zoomed = ""
    if pane:tab():get_size().rows ~= pane:get_dimensions().viewport_rows then
        zoomed = " " .. wezterm.nerdfonts.md_arrow_expand_all .. " "
    end

    -- Build status line with color-coded sections
    local status_items = {
        { Foreground = { Color = "#8AADF4" } },
        { Text = " " .. workspace .. " " },
    }

    if git_branch ~= "" then
        table.insert(status_items, { Foreground = { Color = "#A6DA95" } })
        table.insert(status_items, { Text = git_branch })
    end

    if cmd_count > 0 then
        table.insert(status_items, { Foreground = { Color = "#EED49F" } })
        table.insert(
            status_items,
            { Text = " " .. wezterm.nerdfonts.md_console .. " " .. tostring(cmd_count) }
        )
    end

    if error_indicator ~= "" then
        table.insert(status_items, { Foreground = { Color = "#ED8796" } })
        table.insert(status_items, { Text = error_indicator })
    end

    if zoomed ~= "" then
        table.insert(status_items, { Foreground = { Color = "#F5A97F" } })
        table.insert(status_items, { Text = zoomed })
    end

    -- Workspace note (truncated)
    local notes_dir = os.getenv("HOME") .. "/.local/share/wezterm/workspace-notes"
    local note_file = notes_dir .. "/" .. workspace .. ".txt"
    local note_file_handle = io.open(note_file, "r")
    if note_file_handle then
        local note_content = note_file_handle:read("*all"):gsub("^%s*(.-)%s*$", "%1")
        note_file_handle:close()

        if note_content and note_content ~= "" then
            -- Truncate to 40 characters
            local note_preview = note_content:sub(1, 40)
            if #note_content > 40 then
                note_preview = note_preview .. "..."
            end

            table.insert(status_items, { Foreground = { Color = "#C6A0F6" } })
            table.insert(
                status_items,
                { Text = " " .. wezterm.nerdfonts.md_note_text .. " " .. note_preview }
            )
        end
    end

    table.insert(status_items, { Foreground = { Color = "#CAD3F5" } })
    table.insert(status_items, { Text = " " .. date .. " " })

    window:set_right_status(wezterm.format(status_items))
end)

return config
