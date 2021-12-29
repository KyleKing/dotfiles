-- Docs: https://wezfurlong.org/wezterm/config

-- Keybindings: https://wezfurlong.org/wezterm/config/keys.html#default-shortcut--key-binding-assignments
-- CMD N/T/W; CMD 1-9 all work as expected. Use `CMD Shift ] or [` to switch tabs
-- CMD R to reload configuration file
-- Added custom shortcuts specified below for splitting, but kept the defaults for:
--  navigation (CTRL+SHIFT and arrow key)
--  resize (CTRL+SHIFT+ALT and arrow key)
-- There is a nice feature if wanted for leader keys to behave like tmux

local wezterm = require 'wezterm';


-- editor /usr/local/bin/subl --add
--
-- # clear the terminal screen
-- map cmd+k combine : clear_terminal scrollback active : send_text normal,application \x0c
-- # jump to beginning and end of word
-- map alt+left send_text all \x1b\x62
-- map alt+right send_text all \x1b\x66
-- # jump to beginning and end of line
-- map cmd+left send_text all \x01
-- map cmd+right send_text all \x05

return {
  keys = {
    -- Split and run default program with intuitive _ or |
    {key="_", mods="CTRL|SHIFT|ALT",
      action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},
    {key="|", mods="CTRL|SHIFT|ALT",
      action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
    -- Map jumping between words to Mac-Standard keys
    -- https://wezfurlong.org/wezterm/config/lua/keyassignment/SendString.html
    {key="LeftArrow", mods="ALT", action=wezterm.action{SendString="\x1bb"}},
    {key="RightArrow", mods="ALT", action=wezterm.action{SendString="\x1bf"}}
  },

  -- PLANNED: Consider logic for layouts where new panes are different size
  -- https://github.com/wez/wezterm/issues/1124#issue-991315823

  -- Ensure supported font
  font = wezterm.font("Hack Nerd Font Mono"),

  -- Colors: https://wezfurlong.org/wezterm/config/appearance.html
  -- Note that "color_scheme" overrides "colors"
  -- color_scheme = "Firewatch",
  --
  -- Based on "Tokyo Night Storm variant": https://github.com/enkia/tokyo-night-vscode-theme#other-portings
  -- For Wez: https://github.com/wez/wezterm/blob/main/assets/colors/3024%20Day.toml
  colors = {
      -- The default text color
      foreground = "#a9b1d6",
      -- The default background color
      background = "#24283b",

      -- TODO: Overrides the cell background color when the current cell is occupied by the
      -- cursor and the cursor style is set to Block
      cursor_bg = "#52ad70",
      -- TODO: Overrides the text color when the current cell is occupied by the cursor
      cursor_fg = "black",
      -- TODO: Specifies the border color of the cursor when the cursor style is set to Block,
      -- or the color of the vertical or horizontal bar when the cursor style is set to
      -- Bar or Underline.
      cursor_border = "#52ad70",

      -- TODO: the foreground color of selected text
      selection_fg = "black",
      -- TODO: the background color of selected text
      selection_bg = "#fffacd",

      -- TODO: The color of the scrollbar "thumb"; the portion that represents the current viewport
      scrollbar_thumb = "#222222",

      -- TODO: The color of the split lines between panes
      split = "#444444",

      ansi = {"#32344a", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#ad8ee6", "#449dab", "#9699a8"},
      brights = {"#444b6a", "#ff7a93", "#b9f27c", "#ff9e64", "#7da6ff", "#bb9af7", "#0db9d7", "#acb0d0"},
  },

  -- Stylize the Window
  window_decorations = "RESIZE",
  hide_tab_bar_if_only_one_tab = true,

  window_close_confirmation="NeverPrompt",
}
