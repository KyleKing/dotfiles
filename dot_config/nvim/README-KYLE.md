# Personal Notes on Customization (and nvim!)

## NVChad

### NVChad Install

```txt
git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1 && nvim

:PackerUpdate

:TSInstall bash bibtex css dockerfile dot gitattributes hcl html javascript json latex lua make markdown python scss sql toml typescript yaml
```

[NVChad Features](https://nvchad.com/features)

### General Vim

- `<>` indicates that the inner keys need to be typed. `C-` is `ctrl` and `M-` is for meta (`cmd`).
- `<:wq>` is save and quit vs. `<:q!>` quit and discard changes. Press `<ENTER>` to apply
- `<ESC>` normal mode
- Clicking does move the cursor in WezTerm
- Individual Keys (only works in normal mode)
    - `h (left) j (down has '_') k (up) l (right)
    - `i` insert
    - `A` append
    - `r` replace
    - `c` change (when followed by count/motion, will delete and then begin 'insert' mode)
    - `x` delete char under cursor
    - `u` undo and `U` undo all changes on the same line
    - `<C-r>` (`Ctrl r`) to redo
    - `p` put (paste) after/below cursor or `P` before/above cursor
    - `<C-g>` display cursor position
    - `G` to go end of file and `gg` to go to top or `#G` for go to line
- "operator": leader character
    - `d`: delete
- "count": repeats the prior (or subsequent) "operator" and/or "motion"
    - `#+` (1-∞): repetitions
    - `0` move to start of line
    - Example: `2dd` delete the next two lines
- "motion": key after an "operator" and/or "count" that specifies the operation (i.e. `3e` or `dw`)
    - `w`: from cursor to start of next word
    - `e`: from cursor to end of word
    - `$`: from cursor to end of line
- Snippets
    - `dd` cut line into register
    - [`dd` `3k` P` to move a line up `#` times](https://stackoverflow.com/a/741818/3219667)

Left off around line 500 on `<:Tutor>`

- Is `:` the `leader` key?
- How do I display and/or remove trailing white space from the file?
- How do I get the rainbow indent guides?
