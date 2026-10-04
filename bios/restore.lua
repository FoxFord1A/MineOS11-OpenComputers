-- Restore an EEPROM backup created by MineBIOS install.lua.
-- Usage: lua /home/minebios-restore.lua /home/minebios-eeprom.bak.<timestamp>.lua
local component = require("component")
local filesystem = require("filesystem")
local path = ...
if not path or path == "" then
  print("Usage: lua /home/minebios-restore.lua /home/minebios-eeprom-backup.lua")
  return
end
if not filesystem.exists(path) then error("Backup not found: " .. tostring(path)) end
local file, openError = io.open(path, "rb")
if not file then error("Could not open backup: " .. tostring(openError)) end
local code = file:read("*a")
file:close()
if type(code) ~= "string" or #code == 0 then error("Backup file is empty") end
local address = component.list("eeprom")()
if not address then error("No EEPROM component found") end
local eeprom = component.proxy(address)
local before = eeprom.get()
print("This will replace the current EEPROM code with " .. tostring(path) .. " (" .. #code .. " bytes).")
io.write("Type RESTORE EEPROM to continue: ")
if io.read() ~= "RESTORE EEPROM" then print("Cancelled."); return end
local ok, result, err = pcall(eeprom.set, code)
if not ok or result == false or (result == nil and err ~= nil) then error("EEPROM restore failed: " .. tostring(ok and err or result)) end
local verifyOK, restored = pcall(eeprom.get)
if not verifyOK or restored ~= code then
  if type(before) == "string" then pcall(eeprom.set, before) end
  error("Restore verification failed; attempted to put the previous code back")
end
print("EEPROM restored. Restart the computer to boot with the restored firmware.")
