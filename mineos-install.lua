-- MineOS 11 installer for OpenOS (OpenComputers).
-- Run with: lua /home/mineos-install.lua

local filesystem = require("filesystem")

local BASE_URL = "https://raw.githubusercontent.com/FoxFord1A/MineOS11-OpenComputers/main"
local SOURCE_URL = BASE_URL .. "/mineos.lua"
local DEST = "/home/mineos.lua"
local TEMP = DEST .. ".download"
local MAX_BYTES = 300000

local function say(message)
  print("[MineOS installer] " .. tostring(message))
end

local function download(url, path)
  local internet = require("internet")
  local file, openError = io.open(path, "wb")
  if not file then return false, "Не удалось создать временный файл: " .. tostring(openError) end

  local total = 0
  local ok, err = pcall(function()
    local request = internet.request(url, nil, { ["User-Agent"] = "MineOS11-OpenOS-Installer/1.0" })
    for chunk in request do
      if type(chunk) == "string" and #chunk > 0 then
        total = total + #chunk
        if total > MAX_BYTES then error("Файл превышает лимит " .. MAX_BYTES .. " байт") end
        local wrote, writeError = file:write(chunk)
        if not wrote then error("Ошибка записи: " .. tostring(writeError)) end
      end
    end
  end)

  local closeOK, closeError = file:close()
  if not ok then
    pcall(filesystem.remove, path)
    return false, tostring(err)
  end
  if closeOK == nil then
    pcall(filesystem.remove, path)
    return false, "Ошибка закрытия временного файла: " .. tostring(closeError)
  end
  if total < 100 then
    pcall(filesystem.remove, path)
    return false, "С сервера получен пустой или слишком маленький файл. Проверьте, что репозиторий публичный и URL доступен."
  end

  local check = io.open(path, "rb")
  local header = check and check:read(256) or ""
  if check then check:close() end
  if not header:find("MineOS 11", 1, true) then
    pcall(filesystem.remove, path)
    return false, "Скачанный файл не похож на MineOS 11 (возможно, GitHub вернул страницу ошибки)."
  end
  return true, total
end

local function backupName()
  local path = DEST .. ".bak"
  local n = 1
  while filesystem.exists(path) do
    path = DEST .. ".bak" .. n
    n = n + 1
  end
  return path
end

local function main()
  say("Установка MineOS 11 в " .. DEST)
  if not filesystem.exists("/home") then
    local ok, err = filesystem.makeDirectory("/home")
    if not ok and not filesystem.exists("/home") then
      error("Не удалось создать /home: " .. tostring(err))
    end
  end
  pcall(filesystem.remove, TEMP)

  say("Скачиваю исходный файл из GitHub...")
  local ok, result = download(SOURCE_URL, TEMP)
  if not ok then error("Загрузка не удалась: " .. tostring(result)) end

  local backup
  if filesystem.exists(DEST) then
    backup = backupName()
    local moved, moveError = filesystem.rename(DEST, backup)
    if not moved then
      pcall(filesystem.remove, TEMP)
      error("Не удалось сохранить старую версию. " .. tostring(moveError))
    end
  end

  local installed, installError = filesystem.rename(TEMP, DEST)
  if not installed then
    if backup then pcall(filesystem.rename, backup, DEST) end
    pcall(filesystem.remove, TEMP)
    error("Не удалось установить файл: " .. tostring(installError))
  end

  say("Готово! Установлено " .. tostring(result) .. " байт.")
  if backup then say("Предыдущая версия сохранена: " .. backup) end
  say("Запустите командой: lua " .. DEST)
  say("Для веб-доступа нужна Internet Card и разрешённые HTTP-запросы.")
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  print("[MineOS installer] ОШИБКА: " .. tostring(err))
  print("Проверьте интернет-карту, доступность GitHub и свободное место на диске.")
end
