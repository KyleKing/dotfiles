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
local process_icons = {
    ["bash"] = wezterm.nerdfonts.cod_terminal_bash,
    ["btm"] = wezterm.nerdfonts.mdi_chart_donut_variant,
    ["cargo"] = wezterm.nerdfonts.dev_rust,
    ["curl"] = wezterm.nerdfonts.mdi_flattr,
    ["docker"] = wezterm.nerdfonts.linux_docker,
    ["docker-compose"] = wezterm.nerdfonts.linux_docker,
    ["gh"] = wezterm.nerdfonts.dev_github_badge,
    ["git"] = wezterm.nerdfonts.fa_git,
    ["go"] = wezterm.nerdfonts.seti_go,
    ["htop"] = wezterm.nerdfonts.mdi_chart_donut_variant,
    ["lazydocker"] = wezterm.nerdfonts.linux_docker,
    ["lazygit"] = wezterm.nerdfonts.oct_git_compare,
    ["lua"] = wezterm.nerdfonts.seti_lua,
    ["make"] = wezterm.nerdfonts.seti_makefile,
    ["node"] = wezterm.nerdfonts.mdi_hexagon,
    ["nvim"] = wezterm.nerdfonts.custom_vim,
    ["psql"] = "󱤢",
    ["ruby"] = wezterm.nerdfonts.cod_ruby,
    ["sudo"] = wezterm.nerdfonts.fa_hashtag,
    ["usql"] = "󱤢",
    ["vim"] = wezterm.nerdfonts.dev_vim,
    ["wget"] = wezterm.nerdfonts.mdi_arrow_down_box,
    ["zsh"] = wezterm.nerdfonts.dev_terminal,
}

-- Git lookup cache to avoid repeated expensive io.popen calls
local git_cache = {}
local GIT_CACHE_TTL = 600 -- 10 minutes

local function get_cached_git_root(cwd)
    local now = os.time()
    local cached = git_cache[cwd]

    if cached and (now - cached.timestamp) < GIT_CACHE_TTL then return cached.root, cached.is_git_repo end

    local git_root = ""
    local is_git_repo = false

    local handle = io.popen("cd '" .. cwd .. "' 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null")
    if handle then
        git_root = handle:read("*a"):gsub("%s+$", "")
        handle:close()
        if git_root ~= "" then is_git_repo = true end
    end

    git_cache[cwd] = {
        root = git_root,
        is_git_repo = is_git_repo,
        timestamp = now,
    }

    for key, value in pairs(git_cache) do
        if (now - value.timestamp) >= GIT_CACHE_TTL * 2 then git_cache[key] = nil end
    end

    return git_root, is_git_repo
end

-- Return the Tab's current working directory
local function get_cwd(tab)
    -- Note, returns URL Object: https://wezfurlong.org/wezterm/config/lua/pane/get_current_working_dir.html
    return tab.active_pane.current_working_dir.file_path or ""
end

-- Remove all path components and return only the last value
local function remove_abs_path(path) return path:gsub("(.*[/\\])(.*)", "%2") end

-- Get the git root directory name, or fallback to current directory name
local function get_git_dir_name(tab)
    local cwd = get_cwd(tab):gsub("^file://", "")
    local git_root, is_git_repo = get_cached_git_root(cwd)
    if is_git_repo then return remove_abs_path(git_root) end
    return "./" .. remove_abs_path(cwd)
end

-- Return the concise name or icon of the running process for display
local function get_process(tab)
    if not tab.active_pane or tab.active_pane.foreground_process_name == "" then return "[?]" end

    local process_name = remove_abs_path(tab.active_pane.foreground_process_name)

    return process_icons[process_name] or string.format("[%s]", process_name)
end

-- Pretty format the tab title
local function format_title(tab)
    local dir_name = get_git_dir_name(tab)
    local process = get_process(tab)
    return string.format(" %s %s ", process, dir_name)
end

-- Determine if a tab has unseen output since last visited
local function has_unseen_output(tab)
    if not tab.is_active then
        for _, pane in ipairs(tab.panes) do
            if pane.has_unseen_output then return true end
        end
    end
    return false
end

-- Returns manually set title (from `tab:set_title()` or `wezterm cli set-tab-title`) or creates a new one
local function get_tab_title(tab)
    local title = tab.tab_title
    -- if the tab title is explicitly set, take that
    if title and #title > 0 then return title end
    return format_title(tab)
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
    local git_root, is_git_repo = get_cached_git_root(cwd)
    if is_git_repo then return "||" .. git_root end
    return "./" .. cwd
end

-- On format tab title events, override the default handling to return a custom title
-- Docs: https://wezfurlong.org/wezterm/config/lua/window-events/format-tab-title.html
---@diagnostic disable-next-line: unused-local
wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, _hover, _max_width)
    local title = get_tab_title(tab)
    local color = string_to_color(get_git_root_path(tab))

    if tab.is_active then
        return {
            { Attribute = { Intensity = "Bold" } },
            { Background = { Color = color } },
            { Foreground = { Color = select_contrasting_fg_color(color) } },
            { Text = title },
        }
    end
    if has_unseen_output(tab) then
        return {
            { Foreground = { Color = "#EBD168" } },
            { Text = title },
        }
    end
    return title
end)

-- ============================================================================
-- General configuration

local config = wezterm.config_builder()
config.bold_brightens_ansi_colors = true
config.font_size = 13.5
config.initial_cols = 200
config.initial_rows = 60
config.scrollback_lines = 10000

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

    -- Map jumping between words to Standard Mac keys
    -- https://wezfurlong.org/wezterm/config/lua/keyassignment/SendString.html
    { key = "LeftArrow", mods = "ALT", action = act({ SendString = "\x1bb" }) },
    { key = "RightArrow", mods = "ALT", action = act({ SendString = "\x1bf" }) },
    -- Jump between start and end of line using standard: C-a (beginning) or C-e (end)

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
