-- Docs: https://wezfurlong.org/wezterm/config
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

-- Based on: https://github.com/protiumx/.dotfiles/blob/854d4b159a0a0512dc24cbc840af467ac84085f8/stow/wezterm/.config/wezterm/wezterm.lua#L291-L319
local function hasUnseenOutput(tab)
    if not tab.is_active then
        for _, pane in ipairs(tab.panes) do
            if pane.has_unseen_output then
                return true
            end
        end
    end
    return false
end

-- Docs: https://wezfurlong.org/wezterm/config/lua/window-events/format-tab-title.html
-- This function returns the suggested title for a tab.
-- It prefers the title that was set via `tab:set_title()`
-- or `wezterm cli set-tab-title`, but falls back to the
-- title of the active pane in that tab.
local function tab_title(tab_info)
    local title = tab_info.tab_title
    -- if the tab title is explicitly set, take that
    if title and #title > 0 then
        return title
    end
    -- Otherwise, use the title from the active pane in that tab
    return tab_info.active_pane.title
end

-- Convert arbitrary strings to a unique hex value
-- Based on: https://stackoverflow.com/a/3426956/3219667
local function hashCode(str)
    local hash = 0
    for i = 1, #str do
        hash = string.byte(str, i) + ((hash << 5) - hash)
    end
    return hash
end
local function intToHex(i)
    local c = string.format("%06X", i & 0x00FFFFFF)
    return "#" .. (string.rep("0", 6 - #c) .. c):upper()
end
local testColor = intToHex(hashCode("/Users/kyleking/Developer/ProjectA"))
assert(testColor == "#EBD168", "Unexpected color value for test hash (" .. testColor .. ")")

-- Send this function a luminance value between 0.0 and 1.0, and it returns L* which is "perceptual lightness"
-- Based on: https://stackoverflow.com/a/56678483/3219667
local function calculateLuminance(hexColor)
    local color = hexColor:gsub("#", "") -- Remove leading '#'

    -- Extract RGB components from hex color
    local red, green, blue
    red = tonumber(color:sub(1, 2), 16)
    green = tonumber(color:sub(3, 4), 16)
    blue = tonumber(color:sub(5, 6), 16)

    -- Calculate the luminance of the given color and compare against perceived brightness
    return 0.2126 * red / 255 + 0.7152 * green / 255 + 0.0722 * blue / 255
end
local function YtoLstar(luminance)
    assert(0 <= luminance and luminance <= 1, "luminance is not within [0, 1]")
    if luminance <= (216 / 24389) then -- The CIE standard states 0.008856 but 216/24389 is the intent for 0.008856451679036
        return luminance * (24389 / 27) -- The CIE standard states 903.3, but 24389/27 is the intent, making 903.296296296296296
    end
    return luminance ^ (1 / 3) * 116 - 16
end
local function selectContrastingForeground(hexColor)
    local luminance = calculateLuminance(hexColor)
    if YtoLstar(luminance) > 70 then
        return "#000000" -- Black has higher contrast with colors perceived to be "bright"
    end
    return "#FFFFFF" -- White has higher contrast
end
assert(YtoLstar(calculateLuminance("#494CED")) >= 64, "Expected lightness of around 65")
assert(selectContrastingForeground("#494CED") == "#FFFFFF", "Expected higher contrast with white")
assert(selectContrastingForeground("#EBD168") == "#000000", "Expected higher contrast with black")

wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, _hover, _max_width)
    -- local cwd = get_current_working_dir(tab)
    -- local title = string.format(" %s ~ %s  ", get_process(tab), cwd)

    local title = tab_title(tab)
    local color = intToHex(hashCode(title))
    if tab.is_active then
        return {
            { Attribute = { Intensity = "Bold" } },
            { Background = { Color = color } },
            { Foreground = { Color = selectContrastingForeground(color) } },
            { Text = " " .. title .. " " },
        }
    end
    if hasUnseenOutput(tab) then
        return {
            { Attribute = { Intensity = "Bold" } },
            { Foreground = { Color = "#28719c" } },
            { Text = title },
        }
    end
    return title
end)

return {
    bold_brightens_ansi_colors = true,
    initial_cols = 200,
    initial_rows = 60,
    scrollback_lines = 7500,

    keys = {
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
    },

    -- Ensure supported font
    font = wezterm.font_with_fallback({
        "Hack Nerd Font Mono",
        "Fira Code",
    }),

    -- Colors: https://wezfurlong.org/wezterm/config/appearance.html
    -- Note that "color_scheme" overrides "colors"
    -- color_scheme = "Firewatch",
    --
    -- FYI: Consider Evergreen
    -- 	https://git.sr.ht/~maksim/wezterm-everforest/tree/master/item/everforest.toml
    --
    -- Based on "Tokyo Night Storm variant": https://github.com/enkia/tokyo-night-vscode-theme#other-portings
    -- For Wez: https://github.com/wez/wezterm/blob/main/assets/colors/3024%20Day.toml
    colors = {
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
    },

    -- Stylize the Window
    window_decorations = "RESIZE",
    hide_tab_bar_if_only_one_tab = true,
    show_new_tab_button_in_tab_bar = false,
}
