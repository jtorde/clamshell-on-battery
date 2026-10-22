-- display-sleep-guard (Hammerspoon)
-- Disables sleep on battery while >= THRESHOLD external displays are
-- connected; restores normal sleep otherwise, and when Hammerspoon quits.
-- Event-driven via hs.screen.watcher — no polling.
-- See README.md for setup and details.

local THRESHOLD = 1 -- external displays needed to disable sleep.
                    -- 1 recommended: the M3 Air's 2nd display only activates
                    -- AFTER the lid closes; waiting for 2 means the Mac
                    -- sleeps the moment you close the lid on battery.
local SETTLE = 2    -- seconds to let a reconfiguration burst settle

local currentState = nil
local settleTimer = nil

-- Counts external displays via system_profiler (locale-independent, unlike
-- matching screen names like "Built-in ..."). Only runs on display events.
local COUNT_CMD = [[
/usr/sbin/system_profiler SPDisplaysDataType -json 2>/dev/null | /usr/bin/python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print(0); sys.exit()
n = 0
for gpu in data.get("SPDisplaysDataType", []):
    for d in gpu.get("spdisplays_ndrvs", []):
        if d.get("spdisplays_connection_type") != "spdisplays_internal":
            n += 1
print(n)
'
]]

local function setDisableSleep(value)
  if currentState == value then return end
  hs.task.new("/usr/bin/sudo", function(exitCode)
    if exitCode == 0 then
      currentState = value
      print("display-sleep-guard: disablesleep " .. value)
    else
      hs.notify.show("display-sleep-guard",
        "pmset failed", "Check the sudoers rule (sudo -n pmset ...)")
    end
  end, { "-n", "/usr/bin/pmset", "-b", "disablesleep", tostring(value) }):start()
end

local function check()
  hs.task.new("/bin/bash", function(_, stdOut)
    local n = tonumber((stdOut or ""):match("%d+")) or 0
    setDisableSleep(n >= THRESHOLD and 1 or 0)
  end, { "-c", COUNT_CMD }):start()
end

-- Global so the watcher isn't garbage-collected.
displaySleepGuardWatcher = hs.screen.watcher.new(function()
  if settleTimer then settleTimer:stop() end
  settleTimer = hs.timer.doAfter(SETTLE, check)
end)
displaySleepGuardWatcher:start()

-- Restore normal sleep when Hammerspoon quits or reloads its config.
hs.shutdownCallback = function()
  hs.execute("/usr/bin/sudo -n /usr/bin/pmset -b disablesleep 0")
end

check() -- handle whatever is connected right now
