-- Docs: https://wezfurlong.org/wezterm/config

-- Keybindings: https://wezfurlong.org/wezterm/config/keys.html#default-shortcut--key-binding-assignments
-- CMD N/T/W; CMD 1-9 all work as expected. Use `CMD Shift ] or [` to switch tabs
-- CMD R to reload configuration file
-- Added custom shortcuts specified below for splitting, but kept the defaults for:
--  navigation (CTRL+SHIFT and arrow key)
--  resize (CTRL+SHIFT+ALT and arrow key)
-- There is a nice feature if wanted for leader keys to behave like tmux

local wezterm = require 'wezterm';

-- PLANNED: Add the below shortcuts
-- # clear the terminal screen
-- map cmd+k combine : clear_terminal scrollback active : send_text normal,application \x0c
-- # jump to beginning and end of word
-- map alt+left send_text all \x1b\x62
-- map alt+right send_text all \x1b\x66
-- # jump to beginning and end of line
-- map cmd+left send_text all \x01
-- map cmd+right send_text all \x05

-- Source: https://github.com/wez/wezterm/discussions/529#discussioncomment-463888
-- Hyperlinks: https://github.com/wez/wezterm/blob/7deb215303ce1a8e64d48f65ef3e0a1d24fc2fbc/docs/hyperlinks.md#L17
--
-- Use some simple heuristics to determine if we should open it
-- with a text editor in the terminal.
-- Take note! The code in this file runs on your local machine,
-- but a URI can appear for a remote, multiplexed session.
-- WezTerm can spawn the editor in that remote session, but doesn't
-- have access to the file locally, so we can't probe inside the
-- file itself, so we are limited to simple heuristics based on
-- the filename appearance.
function editable(filename)
  -- "foo.bar" -> ".bar"
  local extension = filename:match("^.+(%..+)$")
  if extension then
    -- ".bar" -> "bar"
    extension = extension:sub(2)
    wezterm.log_info(string.format("extension is [%s]", extension))
    local binary_extensions = {
      jpg = true,
      jpeg = true,
      zip = true,
      zg = true,
      -- and so on
    }
    if binary_extensions[extension] then
      -- can't edit binary files
      return false
    end

    -- TODO: Check if file exists. Some files are on external systems and easy to accidentally click
    --  FYI: Best to allow normal "click to highlight" logic to apply (could copy to clipboard if doesn't exist?)
  end

  -- if there is no, or an unknown, extension, then assume
  -- that our trusty editor will do something reasonable

  return true
end

function extract_filename(uri)
  local start, match_end = uri:find("$EDITOR:");
  if start == 1 then
    -- skip past the colon
    return uri:sub(match_end+1)
  end

  -- `file://hostname/path/to/file`
  local start, match_end = uri:find("file:");
  if start == 1 then
    -- skip "file://", -> `hostname/path/to/file`
    local host_and_path = uri:sub(match_end+3)
    local start, match_end = host_and_path:find("/")
    if start then
      -- -> `/path/to/file`
      return host_and_path:sub(match_end)
    end
  end

  return nil
end

wezterm.on("open-uri", function(window, pane, uri)
  local name = extract_filename(uri)
  if name and editable(name) then
    -- Note: if you change your VISUAL or EDITOR environment,
    -- you will need to restart wezterm for this to take effect,
    -- as there isn't a way for wezterm to "see into" your shell
    -- environment and capture it.
    -- FIXME: This isn't retrieving the VISUAL or EDITOR export...
    local editor = os.getenv("VISUAL") or os.getenv("EDITOR") or "/usr/local/bin/subl"

    -- Use "SpawnCommandInNewWindow" or "SplitHorizontal"
    local action = wezterm.action{SplitHorizontal={args={editor, name}}};
    window:perform_action(action, pane);

    -- prevent the default action from opening in a browser
    return false
  end
end)

return {
  hyperlink_rules = {
    -- These are the default rules, but you currently need to repeat
    -- them here when you define your own rules, as your rules override
    -- the defaults

    -- URL with a protocol
    {
      regex = "\\b\\w+://(?:[\\w.-]+)\\.[a-z]{2,15}\\S*\\b",
      format = "$0",
    },

    -- implicit mailto link
    {
        regex = "\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b",
        format = "mailto:$0",
    },

    -- new in nightly builds; automatically highly file:// URIs.
    {
        regex = "\\bfile://\\S*\\b",
        format = "$0"
    },

    -- Now add a new item at the bottom to match things that are probably filenames

    {
      regex = "\\b\\S*/\\S*\\.[a-zA-Z]+\\b",
      format = "$EDITOR:$0"
    },
  },


  keys = {
    -- Split and run default program with intuitive _ or |
    {key="_", mods="CTRL|SHIFT|ALT",
      action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},
    {key="|", mods="CTRL|SHIFT|ALT",
      action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
    -- Map jumping between words to Standard Mac keys
    -- https://wezfurlong.org/wezterm/config/lua/keyassignment/SendString.html
    {key="LeftArrow", mods="ALT", action=wezterm.action{SendString="\x1bb"}},
    {key="RightArrow", mods="ALT", action=wezterm.action{SendString="\x1bf"}},
    -- Map jumping between start and end of line to Standard Mac keys
    {key="LeftArrow", mods="CMD", action=wezterm.action{SendString="\x01"}},
    {key="RightArrow", mods="CMD", action=wezterm.action{SendString="\x05"}}
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

      -- ansi = {"#32344a", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#ad8ee6", "#449dab", "#9699a8"},
      -- brights = {"#444b6a", "#ff7a93", "#b9f27c", "#ff9e64", "#7da6ff", "#bb9af7", "#0db9d7", "#acb0d0"},
      ansi = {"#32344a", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#ad8ee6", "#449dab", "#e1e1e3"},
      brights = {"#444b6a", "#ff7a93", "#b9f27c", "#ff9e64", "#7da6ff", "#bb9af7", "#0db9d7", "#f7f7f7"},
  },

  -- Stylize the Window
  window_decorations = "RESIZE",
  hide_tab_bar_if_only_one_tab = true,

  -- Turn of Y/N on quit, but best to keep it on as it clears all open sessions
  -- window_close_confirmation="NeverPrompt",
}
