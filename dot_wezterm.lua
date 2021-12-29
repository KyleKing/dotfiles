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
  -- color_scheme = "Andromeda",
  color_scheme = "Tomorrow Night Eighties",
  -- color_scheme = "Solarized Dark Higher Contrast",
  -- color_scheme = "SpaceGray Eighties",
  -- color_scheme = "synthwave",

  -- Stylize the Window
  window_decorations = "RESIZE",
  hide_tab_bar_if_only_one_tab = true,

  window_close_confirmation="NeverPrompt",
}
