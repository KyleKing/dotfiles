# mss capture workflow

Pixel-perfect screenshots from Bash when `gif_creator` is unavailable (regular browser
session, not the agent's managed tab group).

## Procedure

1. **Click** UI elements via the `computer` tool.
    This works regardless of which OS window has focus.

1. **Activate the right Chrome window** by matching its URL.
    A bare `tell application "Google Chrome" to activate` picks an arbitrary window when
    several are open, so match instead:

    ```applescript
    tell application "Google Chrome"
        repeat with w in windows
            set tIdx to 1
            repeat with t in tabs of w
                if URL of t contains "localhost:3000" then
                    set active tab index of w to tIdx
                    set index of w to 1
                    activate
                end if
                set tIdx to tIdx + 1
            end repeat
        end repeat
    end tell
    ```

1. **Capture**: `sleep 0.4 && python3 /tmp/capture.py <filename>.png`.
    The sleep lets Chrome finish painting after activation; without it the shot catches a
    partial repaint.

1. **Verify** with `Read` on the output path.

## capture.py

```python
import sys, mss, mss.tools

IMAGES_DIR = "/path/to/project/images"
REGION = {"left": 0, "top": 33, "width": 1512, "height": 949}


def capture(filename):
    with mss.MSS() as sct:
        img = sct.grab(REGION)
        out = f"{IMAGES_DIR}/{filename}"
        mss.tools.to_png(img.rgb, img.size, output=out)
        print(f"saved: {out}")


if __name__ == "__main__":
    capture(sys.argv[1])
```

`REGION` is display-specific. `top: 33` skips the macOS menu bar; `width` and `height`
match the Chrome window size.

## Interruption to watch for

macOS permission dialogs (for example the WezTerm screen recording prompt) overlay
Chrome and corrupt the capture.
`osascript keystroke return` needs Accessibility permission and often will not dismiss
them, so ask the user to click Allow.
