-- MineBIOS 11 firmware for OpenComputers (Lua architecture).
-- This file runs before OpenOS. It intentionally uses only BIOS globals.

local component = component
local computer = computer
local unpack = table.unpack or unpack
local VERSION = "1.0"
local firmware = "MineBIOS 11"
local gpuAddress, screenAddress
local width, height = 80, 25
local selected = 1
local tab = "BOOT"
local status = "Ready"
local devices = {}
local consoleLines = {"MineBIOS 11 firmware console", "Type help for commands."}
local consoleInput = ""

local colors = {
  navy = 0x07182B, panel = 0x102B48, panel2 = 0x173B60,
  cyan = 0x4BD7E8, white = 0xF0F6FC, muted = 0x9DB1C5,
  green = 0x63D7A2, red = 0xFF7373, black = 0x000000,
}

local function invoke(address, method, ...)
  return component.invoke(address, method, ...)
end

local function safeInvoke(address, method, ...)
  local args = {...}
  return pcall(function() return invoke(address, method, unpack(args)) end)
end

local function initDisplay()
  local ok, address = pcall(function() return component.list("gpu")() end)
  if not ok or not address then return false end
  gpuAddress = address
  local screenOK, sAddress = pcall(function() return component.list("screen")() end)
  if not screenOK or not sAddress then return false end
  screenAddress = sAddress
  local bound = safeInvoke(gpuAddress, "bind", screenAddress)
  if not bound then return false end
  local resOK, w, h = safeInvoke(gpuAddress, "getResolution")
  if resOK and w and h then width, height = w, h end
  if width < 50 or height < 16 then
    safeInvoke(gpuAddress, "setResolution", 80, 25)
    local ok2, w2, h2 = safeInvoke(gpuAddress, "getResolution")
    if ok2 and w2 and h2 then width, height = w2, h2 end
  end
  safeInvoke(gpuAddress, "setDepth", 4)
  return true
end

local function paint(fg, bg)
  if not gpuAddress then return end
  safeInvoke(gpuAddress, "setForeground", fg or colors.white)
  safeInvoke(gpuAddress, "setBackground", bg or colors.navy)
end

local function fill(x, y, w, h, char, fg, bg)
  if not gpuAddress or w < 1 or h < 1 then return end
  paint(fg, bg)
  safeInvoke(gpuAddress, "fill", x, y, w, h, char or " ")
end

local function text(x, y, value, maxWidth, fg, bg)
  if not gpuAddress or y < 1 or y > height or x > width then return end
  value = tostring(value or "")
  if maxWidth then value = value:sub(1, math.max(0, maxWidth)) end
  value = value:sub(1, math.max(0, width - x + 1))
  if value == "" then return end
  paint(fg, bg)
  safeInvoke(gpuAddress, "set", x, y, value)
end

local function clear()
  fill(1, 1, width, height, " ", colors.white, colors.navy)
end

local function frame(x, y, w, h, title)
  fill(x, y, w, h, " ", colors.white, colors.panel)
  fill(x, y, w, 1, "-", colors.cyan, colors.panel2)
  fill(x, y + h - 1, w, 1, "-", colors.cyan, colors.panel2)
  fill(x, y, 1, h, "|", colors.cyan, colors.panel2)
  fill(x + w - 1, y, 1, h, "|", colors.cyan, colors.panel2)
  text(x, y, "+", 1, colors.cyan, colors.panel2)
  text(x + w - 1, y, "+", 1, colors.cyan, colors.panel2)
  text(x, y + h - 1, "+", 1, colors.cyan, colors.panel2)
  text(x + w - 1, y + h - 1, "+", 1, colors.cyan, colors.panel2)
  if title then text(x + 2, y, " " .. title .. " ", w - 4, colors.white, colors.panel2) end
end

local function scanDevices()
  devices = {}
  local fsOK, fsIterator = pcall(function() return component.list("filesystem") end)
  if not fsOK or not fsIterator then return end
  for address in fsIterator do
    local label = "Filesystem"
    local labelOK, result = safeInvoke(address, "getLabel")
    if labelOK and type(result) == "string" and result ~= "" then label = result end
    local existsOK, hasInit = safeInvoke(address, "exists", "/init.lua")
    local isDirOK, bootDir = safeInvoke(address, "exists", "/boot/init.lua")
    devices[#devices + 1] = {
      address = address,
      label = label,
      path = (existsOK and hasInit) and "/init.lua" or ((isDirOK and bootDir) and "/boot/init.lua" or "/init.lua"),
      bootable = (existsOK and hasInit) or (isDirOK and bootDir) or false,
    }
  end
  table.sort(devices, function(a, b)
    if a.bootable ~= b.bootable then return a.bootable end
    return a.label < b.label
  end)
  if selected > #devices then selected = math.max(1, #devices) end
end

local function drawHeader()
  clear()
  fill(1, 1, width, 3, " ", colors.white, colors.panel2)
  text(2, 1, firmware, 28, colors.cyan, colors.panel2)
  text(math.max(2, width - 26), 1, "OpenComputers | v" .. VERSION, 25, colors.muted, colors.panel2)
  text(2, 2, "Firmware Setup Utility", 34, colors.white, colors.panel2)
  local names = {"MAIN", "BOOT", "DEVICES", "CONSOLE"}
  local x = 2
  for _, name in ipairs(names) do
    local bg = (tab == name) and colors.cyan or colors.panel
    local fg = (tab == name) and colors.black or colors.white
    fill(x, 4, #name + 4, 1, " ", fg, bg)
    text(x + 2, 4, name, #name, fg, bg)
    x = x + #name + 4
  end
end

local function drawMain()
  local x, y, w, h = 2, 6, width - 4, height - 9
  frame(x, y, w, h, "System overview")
  local bootAddress = computer.getBootAddress() or "not set"
  local architecture = "unknown"
  local archOK, arch = pcall(computer.getArchitecture)
  if archOK and arch then architecture = tostring(arch) end
  text(x + 3, y + 2, "Firmware        " .. firmware .. " v" .. VERSION, w - 6, colors.white, colors.panel)
  text(x + 3, y + 4, "Architecture    " .. architecture, w - 6, colors.white, colors.panel)
  text(x + 3, y + 6, "Memory          " .. tostring(computer.freeMemory()) .. " / " .. tostring(computer.totalMemory()) .. " bytes free / total", w - 6, colors.white, colors.panel)
  text(x + 3, y + 8, "Boot address    " .. tostring(bootAddress), w - 6, colors.white, colors.panel)
  text(x + 3, y + 10, "Storage devices " .. tostring(#devices), w - 6, colors.white, colors.panel)
  text(x + 3, y + 12, "Uptime          " .. tostring(math.floor(computer.uptime())) .. " seconds", w - 6, colors.white, colors.panel)
  text(x + 2, y + h - 2, "Use Boot to choose a startup device, or Console for firmware commands.", w - 4, colors.muted, colors.panel)
end

local function drawBoot()
  local x, y, w, h = 2, 6, width - 4, height - 9
  frame(x, y, w, h, "Boot device priority / startup device")
  if #devices == 0 then
    text(x + 2, y + 2, "No filesystem devices detected.", w - 4, colors.red, colors.panel)
    text(x + 2, y + 4, "Attach a disk with OpenOS, then press R to rescan.", w - 4, colors.muted, colors.panel)
  else
    text(x + 2, y + 1, "Select a device and press Enter to boot its OS loader.", w - 4, colors.muted, colors.panel)
    local visible = math.max(1, h - 4)
    local first = math.max(1, math.min(selected - visible + 1, #devices - visible + 1))
    for i = first, math.min(#devices, first + visible - 1) do
      local row = y + 2 + (i - first)
      local d = devices[i]
      local prefix = (i == selected) and "> " or "  "
      local detail = d.bootable and ("  " .. d.path) or "  (no init.lua found)"
      local title = prefix .. tostring(i) .. ". " .. d.label .. "  [" .. d.address:sub(1, 8) .. "]"
      fill(x + 1, row, w - 2, 1, " ", colors.white, i == selected and colors.panel2 or colors.panel)
      text(x + 2, row, title .. detail, w - 4, i == selected and colors.cyan or colors.white, i == selected and colors.panel2 or colors.panel)
    end
  end
  text(x + 2, y + h - 2, "Enter: boot   R: rescan   C: firmware console", w - 4, colors.muted, colors.panel)
end

local function drawDevices()
  local x, y, w, h = 2, 6, width - 4, height - 9
  frame(x, y, w, h, "Detected hardware components")
  local n, any = 0, false
  for kind in component.list() do
    for address in component.list(kind) do
      any = true
      n = n + 1
      if n <= h - 2 then
        local label = kind .. "  " .. address
        if kind == "filesystem" then
          for _, d in ipairs(devices) do if d.address == address then label = label .. "  (" .. d.label .. ")"; break end end
        end
        text(x + 2, y + n, label, w - 4, colors.white, colors.panel)
      end
    end
  end
  if not any then text(x + 2, y + 2, "No components detected.", w - 4, colors.muted, colors.panel) end
  if n > h - 2 then text(x + 2, y + h - 2, "... and " .. tostring(n - h + 2) .. " more", w - 4, colors.muted, colors.panel) end
end

local function drawConsole()
  local x, y, w, h = 2, 6, width - 4, height - 9
  frame(x, y, w, h, "Firmware console (restricted commands)")
  local maxLines = math.max(1, h - 3)
  local start = math.max(1, #consoleLines - maxLines + 1)
  for i = start, #consoleLines do
    text(x + 2, y + 1 + i - start, consoleLines[i], w - 4, colors.white, colors.panel)
  end
  text(x + 2, y + h - 2, "> " .. consoleInput .. "_", w - 4, colors.cyan, colors.panel)
end

local function draw()
  if not gpuAddress then return end
  local resolutionOK, currentWidth, currentHeight = safeInvoke(gpuAddress, "getResolution")
  if resolutionOK and currentWidth and currentHeight then width, height = currentWidth, currentHeight end
  drawHeader()
  if tab == "MAIN" then drawMain()
  elseif tab == "BOOT" then drawBoot()
  elseif tab == "DEVICES" then drawDevices()
  else drawConsole() end
  fill(1, height - 2, width, 1, " ", colors.white, colors.panel2)
  text(2, height - 2, status, width - 3, colors.white, colors.panel2)
  text(2, height, "Arrows: navigate | Enter: select | 1-4: pages | Esc: Boot menu", width - 4, colors.muted, colors.navy)
end

local function readFile(address, path)
  local ok, handle = safeInvoke(address, "open", path, "r")
  if not ok or not handle then return nil, tostring(handle or "open failed") end
  local chunks, total = {}, 0
  while total < 1048576 do
    local readOK, chunk = safeInvoke(address, "read", handle, 4096)
    if not readOK then safeInvoke(address, "close", handle); return nil, tostring(chunk) end
    if not chunk then break end
    if type(chunk) ~= "string" then safeInvoke(address, "close", handle); return nil, "invalid read result" end
    if #chunk == 0 then break end
    total = total + #chunk
    chunks[#chunks + 1] = chunk
  end
  safeInvoke(address, "close", handle)
  if total >= 1048576 then return nil, "file exceeds 1 MiB safety limit" end
  return table.concat(chunks)
end

local function bootDevice(index, path)
  local d = devices[index]
  if not d then status = "Invalid boot device number"; draw(); return end
  path = path or d.path or "/init.lua"
  if path:sub(1, 1) ~= "/" or path:find("..", 1, true) then
    status = "Boot path must be an absolute path without '..'"
    draw()
    return
  end
  status = "Loading " .. path .. " from " .. d.label .. "..."
  draw()
  local setOK, setError = pcall(computer.setBootAddress, d.address)
  local source, readError = readFile(d.address, path)
  if not source then status = "Read failed: " .. tostring(readError); draw(); return end
  local loader, compileError = load(source, "=" .. d.label .. ":" .. path)
  if not loader then status = "Syntax error: " .. tostring(compileError); draw(); return end
  local runOK, runError = pcall(loader)
  if not runOK then status = "Boot error: " .. tostring(runError); draw(); return end
  if not setOK then status = "Booted, but boot address was not saved: " .. tostring(setError)
  else status = "Boot program returned; firmware remains active" end
  draw()
end

local function appendLine(line)
  consoleLines[#consoleLines + 1] = tostring(line)
  while #consoleLines > 100 do table.remove(consoleLines, 1) end
end

local function listComponents()
  local n = 0
  for kind in component.list() do
    for address in component.list(kind) do
      n = n + 1
      appendLine(kind .. " " .. address)
    end
  end
  if n == 0 then appendLine("No components found") end
end

local function runCommand(line)
  line = line:gsub("^%s+", ""):gsub("%s+$", "")
  if line == "" then return end
  appendLine("> " .. line)
  local command, rest = line:match("^(%S+)%s*(.-)%s*$")
  command = (command or ""):lower()
  if command == "help" then
    appendLine("help | devices | scan | info | boot N [/path] | clear | reboot | off")
  elseif command == "devices" then listComponents()
  elseif command == "scan" then scanDevices(); appendLine("Filesystem scan complete: " .. #devices .. " device(s)")
  elseif command == "info" then
    appendLine(firmware .. " v" .. VERSION)
    appendLine("Uptime: " .. tostring(math.floor(computer.uptime())) .. " s")
    appendLine("Memory: " .. tostring(computer.freeMemory()) .. "/" .. tostring(computer.totalMemory()) .. " bytes free/total")
    appendLine("Filesystems: " .. #devices)
  elseif command == "boot" then
    local n, path = rest:match("^(%d+)%s*(.*)$")
    if not n then appendLine("Usage: boot N [/path.lua]")
    else bootDevice(tonumber(n), path ~= "" and path or nil) end
  elseif command == "clear" then consoleLines = {}
  elseif command == "reboot" then computer.shutdown(true)
  elseif command == "off" or command == "shutdown" then computer.shutdown(false)
  else appendLine("Unknown command. Type help.") end
end

local function handleTouch(x, y)
  local tabX = 2
  if y == 4 then
    if x >= tabX and x < tabX + 8 then tab = "MAIN"
    elseif x >= tabX + 8 and x < tabX + 16 then tab = "BOOT"
    elseif x >= tabX + 16 and x < tabX + 27 then tab = "DEVICES"
    elseif x >= tabX + 27 then tab = "CONSOLE" end
    return
  end
  if tab == "BOOT" and y >= 8 and y < height - 4 then
    local index = y - 7
    if index >= 1 and index <= #devices then
      selected = index
      bootDevice(index)
    end
  end
end

local function run()
  scanDevices()
  if not initDisplay() then
    error("MineBIOS: GPU and screen are required for setup. Use the OpenComputers default BIOS to boot or attach a screen.")
  end
  draw()
  while true do
    local signal = {computer.pullSignal(0.25)}
    local name = signal[1]
    if name == "key_down" then
      local char, code = signal[3] or 0, signal[4] or 0
      if tab == "CONSOLE" and (code == 28 or code == 156 or char == 13) then
        local command = consoleInput
        consoleInput = ""
        runCommand(command)
      elseif tab == "CONSOLE" and code ~= 200 and code ~= 208 and code ~= 1 then
        if code == 14 or char == 8 or char == 127 then
          consoleInput = consoleInput:sub(1, -2)
        elseif char >= 32 and char <= 126 then
          consoleInput = consoleInput .. string.char(char)
        end
      elseif code == 200 then
        if tab == "BOOT" and #devices > 0 then selected = math.max(1, selected - 1) end
      elseif code == 208 then
        if tab == "BOOT" and #devices > 0 then selected = math.min(#devices, selected + 1) end
      elseif code == 28 or code == 156 or char == 13 then
        if tab == "BOOT" then bootDevice(selected)
        elseif tab ~= "CONSOLE" then tab = "BOOT" end
      elseif code == 1 then
        tab = "BOOT"
      elseif char == string.byte("1") then tab = "MAIN"
      elseif char == string.byte("2") then tab = "BOOT"
      elseif char == string.byte("3") then tab = "DEVICES"
      elseif char == string.byte("4") then tab = "CONSOLE"
      elseif char == string.byte("r") or char == string.byte("R") then scanDevices() end
      draw()
    elseif name == "touch" then
      handleTouch(signal[3] or 0, signal[4] or 0)
      draw()
    end
  end
end

run()
