-- Wezterm Docs: https://wezfurlong.org/wezterm/config/lua/general.html
--  Debug logs in: `lst $HOME/.local/share/wezterm` (Docs: https://wezfurlong.org/wezterm/troubleshooting.html#increasing-log-verbosity)

-- Keybindings: https://wezfurlong.org/wezterm/config/keys.html#default-shortcut--key-binding-assignments
--  CMD N/T/W; CMD 1-9 all work as expected. Use `CMD Shift ] or [` to switch tabs
--  CMD R to reload configuration file
--  To clear scrollback, use both CMD-k and <C-l> in any order (or enter 'clear')
--  Searching scrollback: https://wezfurlong.org/wezterm/scrollback.html?highlight=clear#searching-the-scrollback
--   Ctrl|Shift|f w/ up and down arrows (or pgUp/pgDown) to navigate
--   Ctrl-U to clear and Ctrl-R to switch pattern matching mode
--   Copy Mode: https://wezfurlong.org/wezterm/copymode.html
--    Ctrl|Shift|X to enter copy mode
--    Ctrl|Shift|C to copy to clipboard
--    etc.

-- Example User Configs: https://github.com/wez/wezterm/discussions/628

local wezterm = require("wezterm")

-- ============================================================================
-- Configuration for Tab Color

-- Based on: https://github.com/protiumx/.dotfiles/blob/854d4b159a0a0512dc24cbc840af467ac84085f8/stow/wezterm/.config/wezterm/wezterm.lua#L291-L319
-- Icons from: https://www.nerdfonts.com/cheat-sheet
local process_icons = {
    ["bash"] = wezterm.nerdfonts.md_bash,
    ["btm"] = wezterm.nerdfonts.mdi_chart_donut_variant,
    ["cargo"] = wezterm.nerdfonts.dev_rust,
    ["chezmoi"] = wezterm.nerdfonts.md_sync,
    ["claude"] = wezterm.nerdfonts.md_robot_outline,
    ["curl"] = wezterm.nerdfonts.mdi_flattr,
    ["docker"] = wezterm.nerdfonts.md_docker,
    ["docker-compose"] = wezterm.nerdfonts.md_docker,
    ["gh"] = wezterm.nerdfonts.dev_github_badge,
    ["git"] = wezterm.nerdfonts.fa_git,
    ["go"] = wezterm.nerdfonts.seti_go,
    ["htop"] = wezterm.nerdfonts.mdi_chart_donut_variant,
    ["lazydocker"] = wezterm.nerdfonts.md_docker,
    ["lazygit"] = wezterm.nerdfonts.dev_git_branch,
    ["lua"] = wezterm.nerdfonts.seti_lua,
    ["make"] = wezterm.nerdfonts.seti_makefile,
    ["mise"] = wezterm.nerdfonts.md_carrot,
    ["node"] = wezterm.nerdfonts.cod_json,
    ["nvim"] = wezterm.nerdfonts.linux_neovim,
    ["opentofu"] = wezterm.nerdfonts.md_dump_truck,
    ["psql"] = wezterm.nerdfonts.md_database,
    ["pulumi"] = wezterm.nerdfonts.md_dump_truck,
    ["python"] = wezterm.nerdfonts.dev_python,
    ["ruby"] = wezterm.nerdfonts.cod_ruby,
    ["sudo"] = wezterm.nerdfonts.fa_hashtag,
    ["terraform"] = wezterm.nerdfonts.md_dump_truck,
    ["usql"] = wezterm.nerdfonts.md_database,
    ["uv"] = wezterm.nerdfonts.dev_python,
    ["vim"] = wezterm.nerdfonts.dev_vim,
    ["wget"] = wezterm.nerdfonts.mdi_arrow_down_box,
    ["zsh"] = wezterm.nerdfonts.cod_terminal_bash,
}

local icon_git_root = "./"
local icon_not_git = wezterm.nerdfonts.md_map_marker_radius

-- Unicode spacing characters for refined typography
local nbsp = "\u{00A0}" -- Non-breaking space
local hair = "\u{200A}" -- Hair space (thinnest)
local en = "\u{2002}" -- En space (medium width)

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
    local pane = tab.active_pane
    if not pane or not pane.current_working_dir then return "" end
    return pane.current_working_dir.file_path or ""
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
    -- Strip version numbers (e.g., python3.14 -> python, node24 -> node)
    local base_name = process_name:gsub("%d[%.%d]*$", "")

    return process_icons[base_name] or process_icons[process_name] or string.format("[%s]", process_name)
end

-- Abbreviate string to max_len with ".." suffix if needed
local function abbreviate(str, max_len)
    if #str <= max_len then return str end
    return str:sub(1, max_len - 2) .. ".."
end

-- Format the main content of the tab (everything except edge whitespace)
-- compact: use tighter spacing and abbreviated names for inactive tabs
local function format_tab_content(tab, compact)
    local dir_name = get_git_dir_name(tab)
    local depth_indicator = get_git_depth_indicator(tab)

    if compact then
        -- Compact mode for inactive tabs: abbreviate and use minimal spacing
        dir_name = abbreviate(dir_name, 12)
        return string.format("%s%s%s%s", hair, dir_name, hair, depth_indicator)
    end

    -- Active tab: full width with centered padding
    local min_width = 10
    local dir_len = #dir_name
    if dir_len < min_width then
        local padding = min_width - dir_len
        local left_pad = math.floor(padding / 2)
        local right_pad = padding - left_pad
        dir_name = string.rep(" ", left_pad) .. dir_name .. string.rep(" ", right_pad)
    end

    -- Use refined spacing: hair space near icons, en space for content separation
    return string.format("%s%s%s%s", hair, en, dir_name, en)
end

-- Helper to add a segment to the format table
local function add_segment(format, bg_color, fg_color, text, bold)
    table.insert(format, { Background = { Color = bg_color } })
    table.insert(format, { Foreground = { Color = fg_color } })
    if bold then table.insert(format, { Attribute = { Intensity = "Bold" } }) end
    table.insert(format, { Text = text })
end

-- Convert arbitrary strings to a unique hex color using constrained HSL
-- Goals: muted/sophisticated tones, good variety, readable with black/white text
local function string_to_color(str)
    -- Use only the directory name (last path component) for better hash distribution
    local name = str:match("([^/]+)$") or str

    -- djb2 hash with better mixing
    local hash = 5381
    for i = 1, #name do
        hash = ((hash * 33) + string.byte(name, i)) % (2 ^ 31)
    end
    hash = ((hash * 31337) + 12345) % (2 ^ 31)

    -- Generate hue from hash (full spectrum, 0-360)
    local h_deg = hash % 360

    -- Muted saturation range: 25-45% (avoids both gray and highlighter)
    local sat_index = math.floor(hash / 360) % 5
    local saturations = { 0.25, 0.30, 0.35, 0.40, 0.45 }
    local s = saturations[sat_index + 1]

    -- Comfortable lightness range: 55-75% (readable, not too dark or bright)
    local light_index = math.floor(hash / 1800) % 5
    local lightnesses = { 0.55, 0.60, 0.65, 0.70, 0.75 }
    local l = lightnesses[light_index + 1]

    local color = wezterm.color.from_hsla(h_deg, s, l, 1.0)
    local r, g, b, _ = color:srgba_u8()
    return string.format("#%02X%02X%02X", r, g, b)
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

-- Inline tests for color functions
local function run_color_tests()
    local failures = {}

    local testColor = string_to_color("/Users/kyleking/Developer/ProjectA")
    if not testColor:match("^#%x%x%x%x%x%x$") then
        table.insert(failures, "string_to_color: invalid hex format (" .. testColor .. ")")
    end

    local contrast_tests = {
        { "#494CED", "#FFFFFF", "dark blue needs white text" },
        { "#128b26", "#FFFFFF", "dark green needs white text" },
        { "#58f5a6", "#000000", "bright green needs black text" },
        { "#EBD168", "#000000", "yellow needs black text" },
    }
    for _, test in ipairs(contrast_tests) do
        local bg, expected_fg, desc = test[1], test[2], test[3]
        local actual_fg = select_contrasting_fg_color(bg)
        if actual_fg ~= expected_fg then
            table.insert(
                failures,
                string.format("contrast %s: expected %s, got %s (%s)", bg, expected_fg, actual_fg, desc)
            )
        end
    end

    local color_names = {
        "calcipy",
        "chezmoi",
        "mdformat",
        "mdformat-gfm-alerts",
        "mdformat-mkdocs",
        "tail-jsonl",
        "textract-py3",
        "yak-shears",
    }
    local color_results = {}
    for _, name in ipairs(color_names) do
        color_results[name] = string_to_color(name)
    end
    wezterm.log_info("Generated colors: " .. wezterm.json_encode(color_results))

    if #failures > 0 then wezterm.log_error("Color test failures:\n  " .. table.concat(failures, "\n  ")) end
    return #failures == 0
end
run_color_tests()

-- Get full git root path for color hashing (not just the name)
local function get_git_root_path(tab)
    local cwd = get_cwd(tab):gsub("^file://", "")
    local git_root, is_git_repo, _ = get_cached_git_root(cwd)
    if is_git_repo then return git_root end
    return cwd
end

-- Helper function to dim colors for inactive tabs
local function dim_color(hex_color, l_reduction, s_reduction)
    l_reduction = l_reduction or 0.8 -- default: reduce lightness to 80%
    s_reduction = s_reduction or 0.8 -- default: reduce saturation to 80%

    local color = wezterm.color.parse(hex_color)
    -- hsla() returns h in degrees (0-360), s/l in 0-1 range
    local h, s, l, a = color:hsla()
    l = l * l_reduction
    s = s * s_reduction
    local dimmed = wezterm.color.from_hsla(h, s, l, a)
    local r, g, b, _ = dimmed:srgba_u8()
    return string.format("#%02X%02X%02X", r, g, b)
end

-- Test dim_color preserves hue (blue stays blue, not red)
local function test_dim_color()
    local blue = "#5D7DD0"
    local dimmed = dim_color(blue)
    local orig_color = wezterm.color.parse(blue)
    local dimmed_color = wezterm.color.parse(dimmed)
    local h1, _, _, _ = orig_color:hsla()
    local h2, _, _, _ = dimmed_color:hsla()
    local hue_diff = math.abs(h1 - h2)
    if hue_diff > 2.0 then -- 2 degree tolerance (hsla returns degrees 0-360)
        wezterm.log_error(string.format("dim_color hue drift: %s -> %s (hue %.1f -> %.1f)", blue, dimmed, h1, h2))
    end
end
test_dim_color()

-- On format tab title events, override the default handling to return a custom title
-- Docs: https://wezfurlong.org/wezterm/config/lua/window-events/format-tab-title.html
---@diagnostic disable-next-line: unused-local
wezterm.on("format-tab-title", function(tab, tabs, _panes, _config, _hover, _max_width)
    local base_color = string_to_color(get_git_root_path(tab))
    local off_white = "#ffffff"
    local off_black = "#181825"

    -- Handle custom titles
    if tab.tab_title and #tab.tab_title > 0 then
        local bg_color = tab.is_active and "#F5F5F5" or dim_color(base_color)
        local fg_color = select_contrasting_fg_color(bg_color)
        local format = {}
        local padding = tab.is_active and (nbsp .. nbsp) or nbsp
        add_segment(format, bg_color, fg_color, padding .. tab.tab_title .. padding, true)
        return format
    end

    local format = {}

    if tab.is_active then
        -- Active tab: colored accent bar with right-pointing triangle, off-white main section
        local content = format_tab_content(tab, false)
        local accent_bg = base_color
        local accent_fg = select_contrasting_fg_color(accent_bg)
        local triangle = "▶"

        add_segment(format, accent_bg, accent_fg, " " .. triangle .. " ", true)
        add_segment(format, off_white, off_black, content .. " ", true)
    else
        -- Inactive tab: check if same repo as active tab
        local this_git_root = get_git_root_path(tab)
        local active_git_root = nil
        for _, t in ipairs(tabs) do
            if t.is_active then
                active_git_root = get_git_root_path(t)
                break
            end
        end

        local is_same_repo = active_git_root and this_git_root == active_git_root
        local content = format_tab_content(tab, true) -- compact mode
        local bg_color = dim_color(base_color, 0.8)
        local fg_color = select_contrasting_fg_color(bg_color)
        local process = get_process(tab)

        if is_same_repo then
            -- Same repo as active: white accent behind process icon
            add_segment(format, off_black, off_white, " " .. process .. " ", true)
            add_segment(format, bg_color, fg_color, content, false)
        else
            -- Different repo: process icon with dimmed background
            add_segment(format, bg_color, fg_color, " " .. process .. " " .. content, false)
        end
    end

    return format
end)

-- ============================================================================
-- Sort tabs by directory path with git-aware grouping

local function sort_tabs_by_path(window)
    local mux_window = window:mux_window()
    local tabs = mux_window:tabs()

    -- Build sorting data for each tab
    local tab_data = {}
    for idx, tab in ipairs(tabs) do
        local pane = tab:active_pane()
        if pane then
            local cwd_url = pane:get_current_working_dir()
            if cwd_url then
                local cwd = cwd_url.file_path or ""
                local git_root, is_git_repo, _ = get_cached_git_root(cwd)

                table.insert(tab_data, {
                    tab = tab,
                    cwd = cwd,
                    git_root = is_git_repo and git_root or cwd,
                    is_git_repo = is_git_repo,
                    original_index = idx - 1, -- 0-based for MoveTab
                })
            end
        end
    end

    -- Sort by git root first, then preserve original order within each repo
    table.sort(tab_data, function(a, b)
        if a.git_root ~= b.git_root then return a.git_root < b.git_root end
        return a.original_index < b.original_index
    end)

    -- Move tabs to their sorted positions
    for new_index, data in ipairs(tab_data) do
        local target_index = new_index - 1 -- 0-based
        if data.original_index ~= target_index then
            -- Activate the tab first, then move it
            data.tab:activate()
            window:perform_action(wezterm.action.MoveTab(target_index), data.tab:active_pane())
        end
    end
end

-- ============================================================================
-- Right Status Bar (shows zoom state and other info)

wezterm.on("update-right-status", function(window, _pane)
    local elements = {}

    -- Show ZOOMED indicator when pane is zoomed
    local tab = window:active_tab()
    local is_zoomed = false
    if tab then
        local tab_panes = tab:panes_with_info()
        for _, p in ipairs(tab_panes) do
            if p.is_zoomed then
                is_zoomed = true
                break
            end
        end
    end

    if is_zoomed then
        -- Prominent ZOOMED indicator with orange background (Catppuccin Frappe peach color)
        table.insert(elements, { Foreground = { Color = "#303446" } }) -- Dark blue background color
        table.insert(elements, { Background = { Color = "#ef9f76" } }) -- Peach/orange
        table.insert(elements, { Attribute = { Intensity = "Bold" } })
        table.insert(elements, { Text = " " .. wezterm.nerdfonts.cod_screen_full .. " ZOOMED " })

        -- Separator
        table.insert(elements, { Foreground = { Color = "#ef9f76" } })
        table.insert(elements, { Background = { Color = "#414559" } })
        table.insert(elements, { Text = "" }) -- Powerline separator
    end
    window:set_right_status(wezterm.format(elements))
end)

-- ============================================================================
-- General configuration

local config = wezterm.config_builder()
config.bold_brightens_ansi_colors = true
config.font_size = 13.5
config.initial_cols = 200
config.initial_rows = 60
config.scrollback_lines = 10000

-- Make inactive panes visually distinct
config.inactive_pane_hsb = {
    hue = 1.0,
    saturation = 0.5, -- Desaturate to 50% (more gray/black and white)
    brightness = 0.7, -- Dim to 70%
}

local act = wezterm.action
config.keys = {
    {
        key = "w",
        mods = "CMD",
        action = wezterm.action.CloseCurrentTab({ confirm = true }),
    },
    -- Map tab navigation
    { key = "LeftArrow", mods = "CMD|ALT", action = act({ ActivateTabRelative = -1 }) },
    { key = "RightArrow", mods = "CMD|ALT", action = act({ ActivateTabRelative = 1 }) },
    -- Sort tabs by directory path (git-aware)
    {
        key = "s",
        mods = "CMD|SHIFT",
        action = wezterm.action_callback(function(window, _pane) sort_tabs_by_path(window) end),
    },

    -- Map jumping between words to Standard Mac keys
    -- https://wezfurlong.org/wezterm/config/lua/keyassignment/SendString.html
    { key = "LeftArrow", mods = "ALT", action = act({ SendString = "\x1bb" }) },
    { key = "RightArrow", mods = "ALT", action = act({ SendString = "\x1bf" }) },
    -- Jump between start and end of line using standard: C-a (beginning) or C-e (end)

    -- Map pane splitting and zoom (like tmux)
    { key = "DownArrow", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "RightArrow", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "z", mods = "CTRL|SHIFT", action = act.TogglePaneZoomState },
    -- Note: in nvim, you can use: <C-w>T (moves current window to new tab) for similar behavior

    -- Navigate between panes (Cmd+Ctrl+Arrow)
    { key = "UpArrow", mods = "CMD|CTRL", action = act.ActivatePaneDirection("Up") },
    { key = "DownArrow", mods = "CMD|CTRL", action = act.ActivatePaneDirection("Down") },
    { key = "LeftArrow", mods = "CMD|CTRL", action = act.ActivatePaneDirection("Left") },
    { key = "RightArrow", mods = "CMD|CTRL", action = act.ActivatePaneDirection("Right") },

    -- Map vim-friendly scrolling
    { key = "b", mods = "CTRL", action = act.ScrollByPage(-0.9) },
    { key = "f", mods = "CTRL", action = act.ScrollByPage(0.9) },
    { key = "DownArrow", mods = "CMD", action = act.ScrollToBottom },
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

-- Colors & Appearance Docs: https://wezfurlong.org/wezterm/config/appearance.html
--
-- -- Based on "Tokyo Night Storm variant": https://github.com/tokyo-night/tokyo-night-vscode-theme/blob/master/README.md#other-ports
-- --  For Wez: https://github.com/wez/iTerm2-Color-Schemes/blob/0966005b775691cb757a6be8db56a34a779960b9/wezterm/3024%20Day.toml
-- config.colors = {
--     -- The default text color
--     foreground = "#a9b1d6",
--     -- The default background color
--     background = "#24283b",
--
--     -- Overrides the cell background color when the current cell is occupied by the
--     -- cursor and the cursor style is set to Block
--     cursor_bg = "#52ad70",
--     -- Overrides the text color when the current cell is occupied by the cursor
--     cursor_fg = "#1E212F",
--     -- Specifies the border color of the cursor when the cursor style is set to Block,
--     -- or the color of the vertical or horizontal bar when the cursor style is set to
--     -- Bar or Underline.
--     cursor_border = "#52ad70",
--
--     -- the foreground color of selected text
--     selection_fg = "#1E212F",
--     -- the background color of selected text
--     selection_bg = "#fffacd",
--
--     -- The color of the scrollbar "thumb"; the portion that represents the current viewport
--     scrollbar_thumb = "#222222",
--
--     -- The color of the split lines between panes
--     split = "#444444",
--
--     -- Order from: https://cli.r-lib.org/reference/ansi_palettes.html
--     -- blck red  grn  yllw blue mgnt cyan whte
--     ansi = { "#32344a", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#ad8ee6", "#449dab", "#e1e1e3" },
--     brights = { "#757DA1", "#ff7a93", "#b9f27c", "#ff9e64", "#7da6ff", "#bb9af7", "#0db9d7", "#f7f7f7" },
-- }
--
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

return config
