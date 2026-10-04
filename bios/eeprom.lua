-- MineBIOS 11 stage-1 EEPROM bootstrap for OpenComputers Lua architecture.
-- Keep this file under the EEPROM's 4 KiB code limit.
local c, m = component, computer
local function stop(message)
  pcall(function()
    local g = c.list("gpu")()
    local s = c.list("screen")()
    if g and s then
      c.invoke(g, "bind", s)
      c.invoke(g, "setBackground", 0x07182B)
      c.invoke(g, "setForeground", 0xFF7373)
      c.invoke(g, "fill", 1, 1, 60, 5, " ")
      c.invoke(g, "set", 2, 2, "MineBIOS startup error")
      c.invoke(g, "setForeground", 0xFFFFFF)
      c.invoke(g, "set", 2, 3, tostring(message):sub(1, 55))
    end
  end)
  while true do m.pullSignal(1) end
end
local addresses = {}
local preferred = m.getBootAddress()
if preferred then addresses[#addresses + 1] = preferred end
for address in c.list("filesystem") do
  if address ~= preferred then addresses[#addresses + 1] = address end
end
for _, address in ipairs(addresses) do
  local ok, handle = pcall(c.invoke, address, "open", "/minebios.lua", "r")
  if ok and handle then
    local chunks, total = {}, 0
    while total < 524288 do
      local readOK, chunk = pcall(c.invoke, address, "read", handle, 4096)
      if not readOK or not chunk then break end
      if type(chunk) ~= "string" then break end
      total = total + #chunk
      chunks[#chunks + 1] = chunk
    end
    pcall(c.invoke, address, "close", handle)
    local source = table.concat(chunks)
    if #source > 0 and total < 524288 then
      local fn, err = load(source, "=MineBIOS:/minebios.lua")
      if fn then
        local ran, result = pcall(fn)
        if not ran then stop(result) end
        stop("BIOS returned unexpectedly")
      else
        stop(err)
      end
    end
  end
end
stop("No /minebios.lua found on any filesystem. Restore the firmware or attach a BIOS disk.")
