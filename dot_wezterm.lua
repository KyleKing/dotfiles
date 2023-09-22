-- Docs: https://wezfurlong.org/wezterm/config

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
-- local act = wezterm.action

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
}
