-- MineBIOS 11 installer for OpenOS. Run only when you intend to replace EEPROM firmware.
-- Download: wget -f https://raw.githubusercontent.com/FoxFord1A/MineOS11-OpenComputers/main/bios/install.lua /home/minebios-install.lua
-- Run: lua /home/minebios-install.lua
local component = require("component")
local filesystem = require("filesystem")
local internet = require("internet")
local BASE = "https://raw.githubusercontent.com/FoxFord1A/MineOS11-OpenComputers/main/bios"
local BIOS_URL = BASE .. "/minebios.lua"
local EEPROM_URL = BASE .. "/eeprom.lua"
local BIOS_PATH = "/minebios.lua"
local MAX_BOOT_BYTES = 4096

local function say(message) print("[MineBIOS installer] " .. tostring(message)) end

local function download(url, path, minBytes)
  local file, err = io.open(path, "wb")
  if not file then return false, "Cannot create " .. path .. ": " .. tostring(err) end
  local total = 0
  local ok, failure = pcall(function()
    -- Match OpenOS wget's plain GET request; custom headers can fail on some OC versions.
    local requestOK, request, requestError = pcall(internet.request, url)
    if not requestOK then error("HTTP request failed: " .. tostring(request or "no error details")) end
    local requestType = type(request)
    local requestMeta = (requestType == "table" or requestType == "userdata") and getmetatable(request) or nil
    local callable = requestType == "function" or (type(requestMeta) == "table" and type(requestMeta.__call) == "function")
    if not callable then
      error("HTTP request returned no callable response iterator (" .. requestType .. "): " .. tostring(requestError or "no error details"))
    end
    for chunk in request do
      if type(chunk) == "string" and #chunk > 0 then
        total = total + #chunk
        if total > 1048576 then error("Download exceeds 1 MiB limit") end
        local wrote, writeError = file:write(chunk)
        if not wrote then error(writeError or "write failed") end
      end
    end
  end)
  local closeOK, closeError = file:close()
  if not ok then pcall(filesystem.remove, path); return false, tostring(failure or "HTTP response failed without an error message") end
  if closeOK == nil then pcall(filesystem.remove, path); return false, tostring(closeError) end
  if total < (minBytes or 1) then pcall(filesystem.remove, path); return false, "Downloaded file is empty or incomplete" end
  return true, total
end

local function readAll(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local data = f:read("*a")
  f:close()
  return data
end

local function uniquePath(path)
  local stamp = tostring(math.floor(os.time()))
  local candidate = path .. ".bak." .. stamp
  local n = 1
  while filesystem.exists(candidate) do
    candidate = path .. ".bak." .. stamp .. "." .. n
    n = n + 1
  end
  return candidate
end

local function main()
  if not component.isAvailable("eeprom") then error("No EEPROM component found") end
  if not component.isAvailable("filesystem") then error("No filesystem component found") end
  local eepromAddress = component.list("eeprom")()
  if not eepromAddress then error("No EEPROM component found") end
  local eeprom = component.proxy(eepromAddress)

  say("This will replace the computer's EEPROM boot code with MineBIOS 11.")
  say("The existing EEPROM code will first be saved under /home, and the existing /minebios.lua will be backed up.")
  say("Downloading BIOS files before touching EEPROM...")
  local biosTemp, bootTemp = BIOS_PATH .. ".download", "/minebios-eeprom.lua.download"
  pcall(filesystem.remove, biosTemp)
  pcall(filesystem.remove, bootTemp)
  local ok, result = download(BIOS_URL, biosTemp, 1000)
  if not ok then error("BIOS download failed: " .. tostring(result)) end
  ok, result = download(EEPROM_URL, bootTemp, 50)
  if not ok then pcall(filesystem.remove, biosTemp); error("EEPROM bootstrap download failed: " .. tostring(result)) end

  local biosCode, biosReadError = readAll(biosTemp)
  local bootCode, bootReadError = readAll(bootTemp)
  if not biosCode then error("Could not read BIOS payload: " .. tostring(biosReadError)) end
  if not bootCode then error("Could not read EEPROM bootstrap: " .. tostring(bootReadError)) end
  if not biosCode:find("MineBIOS 11 firmware", 1, true) then error("BIOS file verification failed") end
  if not bootCode:find("MineBIOS 11 stage-1", 1, true) then error("EEPROM bootstrap verification failed") end
  if #bootCode > MAX_BOOT_BYTES then error("EEPROM bootstrap is " .. #bootCode .. " bytes; limit is " .. MAX_BOOT_BYTES) end

  local biosBackup
  if filesystem.exists(BIOS_PATH) then
    biosBackup = uniquePath(BIOS_PATH)
    local moved, moveError = filesystem.rename(BIOS_PATH, biosBackup)
    if not moved then error("Could not back up existing " .. BIOS_PATH .. ": " .. tostring(moveError)) end
  end
  local placed, placeError = filesystem.rename(biosTemp, BIOS_PATH)
  if not placed then
    if biosBackup then pcall(filesystem.rename, biosBackup, BIOS_PATH) end
    error("Could not install BIOS payload: " .. tostring(placeError))
  end
  pcall(filesystem.remove, bootTemp)

  local previousCode, getError = eeprom.get()
  if type(previousCode) ~= "string" then error("Could not read current EEPROM code: " .. tostring(getError)) end
  if not filesystem.exists("/home") then
    local made, makeError = filesystem.makeDirectory("/home")
    if not made and not filesystem.exists("/home") then error("Could not create /home: " .. tostring(makeError)) end
  end
  local backupPath = uniquePath("/home/minebios-eeprom") .. ".lua"
  local backup, backupError = io.open(backupPath, "wb")
  if not backup then error("Could not save EEPROM backup: " .. tostring(backupError)) end
  local saved, saveError = backup:write(previousCode)
  local closed, closeError = backup:close()
  if not saved or closed == nil then error("Could not complete EEPROM backup: " .. tostring(saveError or closeError)) end

  say("Current EEPROM code backed up to " .. backupPath)
  say("BIOS payload installed to " .. BIOS_PATH .. " (" .. #biosCode .. " bytes).")
  say("EEPROM bootstrap size: " .. #bootCode .. " / " .. MAX_BOOT_BYTES .. " bytes.")
  io.write("Type INSTALL MINEBIOS to replace firmware, or anything else to cancel: ")
  local answer = io.read()
  if answer ~= "INSTALL MINEBIOS" then
    say("Cancelled. EEPROM was not changed.")
    return
  end

  local setOK, setResult, setError = pcall(eeprom.set, bootCode)
  if not setOK or setResult == false or (setResult == nil and setError ~= nil) then
    say("EEPROM programming failed: " .. tostring(setOK and setError or setResult))
    say("The previous EEPROM code is still backed up at " .. backupPath)
    error("Firmware update failed")
  end
  local verifyOK, verifyCode = pcall(eeprom.get)
  if not verifyOK or verifyCode ~= bootCode then
    pcall(eeprom.set, previousCode)
    error("Firmware verification failed. Tried restoring the previous EEPROM code.")
  end
  say("MineBIOS 11 installed and verified. Restart the computer to open Firmware Setup.")
  say("Recovery backup: " .. backupPath)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  say("ERROR: " .. tostring(err))
  say("If installation did not reach EEPROM programming, the old firmware remains active.")
end
