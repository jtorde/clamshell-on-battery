# clamshell-on-battery

Use two external monitors with a MacBook Air (M3) **on battery** — no power
cable required.

Apple only enables the Air's dual-external-display (clamshell) mode while the
lid is closed, and a closed-lid Mac on battery immediately goes to sleep.
The power-cable "requirement" is really just that sleep. This tool disables
sleep on battery **only while external monitor(s) are connected** and restores
normal sleep behavior the moment they're unplugged, so your Mac still sleeps
normally in a bag.

## How it works

A small Hammerspoon script (`display-sleep-guard.lua`) registers a
display-configuration watcher
(`hs.screen.watcher`), so it reacts instantly to monitors being plugged or
unplugged and uses zero CPU in between — no polling. On each change it counts
external displays (via `system_profiler`, locale-independent) and toggles:

```
pmset -b disablesleep 1   # monitor(s) connected → no sleep on battery
pmset -b disablesleep 0   # none connected → normal behavior
```

`disablesleep` can only be changed by root, so a sudoers rule allows those two
exact commands — and nothing else — to run without a password.

## Files

| File | Installs to | Purpose |
|---|---|---|
| `display-sleep-guard.lua` | `~/.hammerspoon/` | The watcher script |
| `sudoers-display-sleep-guard` | `/etc/sudoers.d/` | Passwordless rule for the two `pmset` commands |

## Requirements

- Apple Silicon MacBook (built for the M3 Air; works on others)
- [Hammerspoon](https://www.hammerspoon.org) (free, open source)
- An administrator account

## Install

From the folder containing these files:

```bash
# 1. Hammerspoon (skip if already installed)
brew install --cask hammerspoon

# 2. Sudoers rule
sudo cp sudoers-display-sleep-guard /etc/sudoers.d/display-sleep-guard
sudo chmod 440 /etc/sudoers.d/display-sleep-guard
sudo visudo -c   # MUST print "parsed OK" — otherwise delete the file:
                 #   sudo rm /etc/sudoers.d/display-sleep-guard

# 3. Script
mkdir -p ~/.hammerspoon
cp display-sleep-guard.lua ~/.hammerspoon/
```

Then add this line **at the top** of `~/.hammerspoon/init.lua` (create the
file if it doesn't exist):

```lua
require("display-sleep-guard")
```

Or do it from the terminal (safe to run twice; creates the file if needed):

```bash
touch ~/.hammerspoon/init.lua
grep -qF 'require("display-sleep-guard")' ~/.hammerspoon/init.lua || \
  { echo 'require("display-sleep-guard")' | cat - ~/.hammerspoon/init.lua > /tmp/init.lua \
    && mv /tmp/init.lua ~/.hammerspoon/init.lua; }
```

Don't append it to the end: if an existing config ends with a `return`
statement, Lua rejects any line after it (`<eof> expected near 'require'`).

Then launch Hammerspoon, grant it Accessibility permission when prompted,
enable **Launch Hammerspoon at login** in its preferences, and click the
menu-bar icon → **Reload Config**.

## Verify

```bash
pmset -g | grep SleepDisabled   # 0 with no monitors connected
# plug in a monitor, wait ~5 seconds
pmset -g | grep SleepDisabled   # should now show 1
# unplug, wait ~5 seconds → back to 0
```

Real-world test: connect both monitors, unplug the charger, close the lid —
both displays should stay live.

## Configuration

Two constants at the top of `display-sleep-guard.lua`:

- `THRESHOLD` (default `1`) — external displays required to disable sleep.
  `1` is deliberate: the M3 Air's second display only activates *after* the
  lid closes, so waiting for a count of 2 would let the Mac fall asleep the
  moment you close the lid. `1` also covers single-monitor clamshell on
  battery, which has the same sleep problem.
- `SETTLE` (default `2`) — seconds to wait for a display reconfiguration
  burst to settle before re-checking.

## Uninstall

```bash
sudo rm /etc/sudoers.d/display-sleep-guard
rm ~/.hammerspoon/display-sleep-guard.lua   # and remove the require line from init.lua
sudo pmset -b disablesleep 0                # reset, just in case
```

## Caveats

- While a monitor is attached, the Mac will **not** sleep on battery even
  with the lid closed — unplug everything before putting it in a bag (the
  guard then restores normal sleep automatically).
- The M3 Air is fanless; driving two external displays with the lid closed
  runs warm and drains the battery quickly. Fine for a meeting, not ideal
  as a daily setup.
- Troubleshooting: `pmset -g` shows the current state; the Hammerspoon
  Console (menu-bar icon → Console) shows the script's log lines. A
  "pmset failed" notification means the sudoers rule isn't in place.
