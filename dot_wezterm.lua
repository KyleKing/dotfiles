-- Docs: https://wezfurlong.org/wezterm/config/lua/general.html
--  Debug logs in: lst $HOME/.local/share/wezterm (Docs: https://wezfurlong.org/wezterm/troubleshooting.html#increasing-log-verbosity)
--
-- Keybindings: https://wezfurlong.org/wezterm/config/keys.html#default-shortcut--key-binding-assignments
-- CMD N/T/W; CMD 1-9 all work as expected. Use `CMD Shift ] or [` to switch tabs
-- CMD R to reload configuration file
-- To clear scrollback, use both CMD-k and <C-l> in any order (or enter 'clear')
-- Added custom shortcuts specified below for splitting, but kept the defaults for:
--  navigation (CTRL+SHIFT and arrow key)
--  resize (CTRL+SHIFT+ALT and arrow key)
-- There is a nice feature if wanted for leader keys to behave like tmux or Sublime origami (i.e. CMD K)
-- https://github.com/zhaohongxuan/dotfiles/blob/3ac55a1c31b9f706b366fb79b2b4328581c9fd91/dot_config/wezterm/wezterm.lua#L26-L38
-- Searching scrollback: https://wezfurlong.org/wezterm/scrollback.html?highlight=clear#searching-the-scrollback
--  Ctrl|Shift|f w/ up and down arrows (or pgUp/pgDown) to navigate
--  Ctrl-U to clear and Ctrl-R to switch pattern matching mode
--  Copy Mode: https://wezfurlong.org/wezterm/copymode.html
--   Ctrl|Shift|X to enter copy mode
--   Ctrl|Shift|C to copy to clipboard
--   etc.

-- Examples
-- https://github.com/wez/wezterm/discussions/628

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
    ["kubectl"] = wezterm.nerdfonts.linux_docker,
    ["kuberlr"] = wezterm.nerdfonts.linux_docker,
    ["lazydocker"] = wezterm.nerdfonts.linux_docker,
    ["lazygit"] = wezterm.nerdfonts.oct_git_compare,
    ["lua"] = wezterm.nerdfonts.seti_lua,
    ["make"] = wezterm.nerdfonts.seti_makefile,
    ["node"] = wezterm.nerdfonts.mdi_hexagon,
    ["nvim"] = wezterm.nerdfonts.custom_vim,
    ["psql"] = "󱤢",
    ["ruby"] = wezterm.nerdfonts.cod_ruby,
    ["stern"] = wezterm.nerdfonts.linux_docker,
    ["sudo"] = wezterm.nerdfonts.fa_hashtag,
    ["usql"] = "󱤢",
    ["vim"] = wezterm.nerdfonts.dev_vim,
    ["wget"] = wezterm.nerdfonts.mdi_arrow_down_box,
    ["zsh"] = wezterm.nerdfonts.dev_terminal,
}

-- Return the Tab's current working directory
local function get_cwd(tab)
    -- Note, returns URL Object: https://wezfurlong.org/wezterm/config/lua/pane/get_current_working_dir.html
    return tab.active_pane.current_working_dir.file_path or ""
end

-- Remove all path components and return only the last value
local function remove_abs_path(path) return path:gsub("(.*[/\\])(.*)", "%2") end

-- Return the pretty path of the tab's current working directory
local function get_display_cwd(tab)
    local current_dir = get_cwd(tab)
    local HOME_DIR = string.format("file://%s", os.getenv("HOME"))
    return current_dir == HOME_DIR and "~/" or remove_abs_path(current_dir)
end

-- Return the concise name or icon of the running process for display
local function get_process(tab)
    if not tab.active_pane or tab.active_pane.foreground_process_name == "" then return "[?]" end

    local process_name = remove_abs_path(tab.active_pane.foreground_process_name)
    if process_name:find("kubectl") then process_name = "kubectl" end

    return process_icons[process_name] or string.format("[%s]", process_name)
end

-- Pretty format the tab title
local function format_title(tab)
    local cwd = get_display_cwd(tab)
    local process = get_process(tab)

    local active_title = tab.active_pane.title
    if active_title:find("- NVIM") then active_title = active_title:gsub("^([^ ]+) .*", "%1") end

    local description = (not active_title or active_title == cwd) and "~" or active_title
    return string.format(" %s %s/ %s ", process, cwd, description)
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
        hash = string.byte(str, i) + ((hash << 5) - hash)
    end

    -- Convert the integer to a unique color
    local c = string.format("%06X", hash & 0x00FFFFFF)
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

-- On format tab title events, override the default handling to return a custom title
-- Docs: https://wezfurlong.org/wezterm/config/lua/window-events/format-tab-title.html
---@diagnostic disable-next-line: unused-local
wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, _hover, _max_width)
    local title = get_tab_title(tab)
    local color = string_to_color(get_cwd(tab))

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
config.initial_cols = 200
config.initial_rows = 60
config.scrollback_lines = 7500

config.keys = {
    {
        key = "w",
        mods = "CMD",
        action = wezterm.action.CloseCurrentTab({ confirm = true }),
    },
    -- Map tab navigation
    { key = "LeftArrow", mods = "CMD|ALT", action = wezterm.action({ ActivateTabRelative = -1 }) },
    { key = "RightArrow", mods = "CMD|ALT", action = wezterm.action({ ActivateTabRelative = 1 }) },

    -- Map jumping between words to Standard Mac keys
    -- https://wezfurlong.org/wezterm/config/lua/keyassignment/SendString.html
    { key = "LeftArrow", mods = "ALT", action = wezterm.action({ SendString = "\x1bb" }) },
    { key = "RightArrow", mods = "ALT", action = wezterm.action({ SendString = "\x1bf" }) },
    -- Map jumping between start and end of line to Standard Mac keys
    { key = "LeftArrow", mods = "CMD", action = wezterm.action({ SendString = "\x01" }) },
    { key = "RightArrow", mods = "CMD", action = wezterm.action({ SendString = "\x05" }) },
}

config.mouse_bindings = {
    -- Ctrl-click will open the link under the mouse cursor
    {
        event = { Up = { streak = 1, button = "Left" } },
        mods = "CTRL",
        action = wezterm.action.OpenLinkAtMouseCursor,
    },
}

-- Ensure supported font
config.font = wezterm.font_with_fallback({
    "Hack Nerd Font Mono",
    "Fira Code",
})

-- Colors: https://wezfurlong.org/wezterm/config/appearance.html
-- Note that "color_scheme" overrides "colors"
-- color_scheme = "Firewatch",
--
-- FYI: Consider Evergreen
-- 	https://git.sr.ht/~maksim/wezterm-everforest/tree/master/item/everforest.toml
--
-- Based on "Tokyo Night Storm variant": https://github.com/enkia/tokyo-night-vscode-theme#other-portings
-- For Wez: https://github.com/wez/wezterm/blob/main/assets/colors/3024%20Day.toml
config.colors = {
    -- The default text color
    foreground = "#a9b1d6",
    -- The default background color
    background = "#24283b",

    -- Overrides the cell background color when the current cell is occupied by the
    -- cursor and the cursor style is set to Block
    cursor_bg = "#52ad70",
    -- Overrides the text color when the current cell is occupied by the cursor
    cursor_fg = "#1E212F",
    -- Specifies the border color of the cursor when the cursor style is set to Block,
    -- or the color of the vertical or horizontal bar when the cursor style is set to
    -- Bar or Underline.
    cursor_border = "#52ad70",

    -- the foreground color of selected text
    selection_fg = "#1E212F",
    -- the background color of selected text
    selection_bg = "#fffacd",

    -- The color of the scrollbar "thumb"; the portion that represents the current viewport
    scrollbar_thumb = "#222222",

    -- The color of the split lines between panes
    split = "#444444",

    -- Order from: https://cli.r-lib.org/reference/ansi_palettes.html
    -- blck red  grn  yllw blue mgnt cyan whte
    ansi = { "#32344a", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#ad8ee6", "#449dab", "#e1e1e3" },
    brights = { "#757DA1", "#ff7a93", "#b9f27c", "#ff9e64", "#7da6ff", "#bb9af7", "#0db9d7", "#f7f7f7" },
}

-- Stylize the Window
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.show_tab_index_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false

return config
