-- MineOS 11 for OpenComputers / OpenOS.
-- Desktop shell with a lightweight HTTP(S) text browser.
-- Requires: GPU + screen. Internet Card required for web access.
-- Start: lua /home/mineos.lua

local component = require("component")
local event = require("event")
local unicode = require("unicode")
local computer = require("computer")

local gpu = component.gpu
if not gpu then error("MineOS 11: не найдена видеокарта GPU") end

local internet
local internetOK, internetLib = pcall(require, "internet")
if internetOK then internet = internetLib end

pcall(function()
  local w, h = gpu.maxResolution()
  if w and h then gpu.setResolution(w, h) end
end)
pcall(function() gpu.setDepth(8) end)

local sw, sh = gpu.getResolution()
local C = {
  blue = 0x164A82,
  blueLight = 0x2E78B8,
  taskbar = 0x10243A,
  taskbarButton = 0x263D58,
  taskbarActive = 0x35618A,
  window = 0xF4F7FB,
  white = 0xFFFFFF,
  ink = 0x172335,
  muted = 0x67758A,
  accent = 0x1479D0,
  border = 0xC8D3E1,
  red = 0xC93C3C,
  green = 0x147A56,
  pale = 0xE6EEF7,
}

local state = {
  app = "desktop",
  startOpen = false,
  powerOpen = false,
  url = "https://example.com",
  pageTitle = "Добро пожаловать",
  pageLines = {
    "Браузер MineOS готов.",
    "",
    "Нажмите адресную строку, введите адрес сайта и нажмите Enter.",
    "Кнопки [<] и [>] переключают историю; [R] обновляет страницу.",
    "",
    "Нужны Internet Card и разрешённые HTTP-запросы OpenComputers.",
    "",
    "Это текстовый браузер: JavaScript, оформление CSS и изображения не поддерживаются.",
  },
  scroll = 0,
  status = "Готово",
  maxBody = 131072,
  history = {},
  historyIndex = 0,
  browserHit = {},
}

local function setColors(fg, bg)
  gpu.setForeground(fg or C.ink)
  gpu.setBackground(bg or C.window)
end

local function fill(x, y, w, h, char, fg, bg)
  if w <= 0 or h <= 0 then return end
  setColors(fg, bg)
  gpu.fill(x, y, w, h, char or " ")
end

local function text(x, y, value, maxWidth, fg, bg)
  if y < 1 or y > sh or x > sw then return end
  value = tostring(value or "")
  if maxWidth then value = unicode.sub(value, 1, math.max(0, maxWidth)) end
  if x + unicode.len(value) - 1 > sw then
    value = unicode.sub(value, 1, math.max(0, sw - x + 1))
  end
  if value == "" then return end
  setColors(fg, bg)
  gpu.set(x, y, value)
end

local function frame(x, y, w, h, bg)
  fill(x, y, w, h, " ", C.ink, bg)
  if w < 2 or h < 2 then return end
  fill(x, y, w, 1, "-", C.ink, bg)
  fill(x, y + h - 1, w, 1, "-", C.ink, bg)
  fill(x, y, 1, h, "|", C.ink, bg)
  fill(x + w - 1, y, 1, h, "|", C.ink, bg)
  text(x, y, "+", 1, C.ink, bg)
  text(x + w - 1, y, "+", 1, C.ink, bg)
  text(x, y + h - 1, "+", 1, C.ink, bg)
  text(x + w - 1, y + h - 1, "+", 1, C.ink, bg)
end

local function taskbarLayout()
  local barW = math.min(sw, math.max(30, math.floor(sw * 0.52)))
  local barX = math.floor((sw - barW) / 2) + 1
  local barY = math.max(1, sh - 2)
  return {
    x = barX, y = barY, w = barW,
    startX = barX,
    webX = barX + 9,
    powerX = barX + 20,
  }
end

local function menuLayout()
  local bar = taskbarLayout()
  local w, h = math.min(36, sw - 4), math.min(12, sh - 5)
  return math.floor((sw - w) / 2) + 1, math.max(1, bar.y - h), w, h
end

local function powerLayout()
  local w, h = math.min(30, sw - 4), math.min(9, sh - 5)
  return math.max(2, sw - w - 2), math.max(1, taskbarLayout().y - h + 1), w, h
end

local function drawStartMenu()
  local x, y, w, h = menuLayout()
  frame(x, y, w, h, C.window)
  fill(x + 1, y + 1, w - 2, 2, " ", C.white, C.accent)
  text(x + 2, y + 1, "Пуск  |  MineOS 11", w - 4, C.white, C.accent)
  text(x + 3, y + 4, "[WWW]  Браузер", w - 6, C.ink, C.window)
  text(x + 3, y + 6, "[ i ]   О системе", w - 6, C.ink, C.window)
  text(x + 3, y + 8, "[⏻]    Питание", w - 6, C.ink, C.window)
  text(x + 2, y + h - 2, "Выберите пункт мышью", w - 4, C.muted, C.window)
end

local function drawPowerMenu()
  local x, y, w, h = powerLayout()
  frame(x, y, w, h, C.window)
  fill(x + 1, y + 1, w - 2, 2, " ", C.white, C.panelButton or C.taskbar)
  text(x + 2, y + 1, "Питание компьютера", w - 4, C.white, C.taskbar)
  text(x + 3, y + 4, "Выключить компьютер", w - 6, C.ink, C.window)
  text(x + 3, y + 6, "Перезагрузить", w - 6, C.ink, C.window)
  text(x + 3, y + 8, "Отмена", w - 6, C.muted, C.window)
end

local function drawDesktop()
  sw, sh = gpu.getResolution()
  fill(1, 1, sw, sh, " ", C.white, C.blue)
  local waveY = math.floor(sh * 0.57)
  fill(1, waveY, sw, sh - waveY + 1, " ", C.white, C.blueLight)

  text(3, 2, "MineOS 11", 30, C.white, C.blue)
  text(3, 3, "Рабочий стол", 30, 0xD9EAF8, C.blue)

  text(4, 6, "+---------+", 13, C.white, C.blue)
  text(4, 7, "|  WWW    |", 13, C.white, C.blue)
  text(4, 8, "+---------+", 13, C.white, C.blue)
  text(4, 9, "Браузер", 14, C.white, C.blue)
  text(4, 12, "+---------+", 13, C.white, C.blue)
  text(4, 13, "|   i     |", 13, C.white, C.blue)
  text(4, 14, "+---------+", 13, C.white, C.blue)
  text(4, 15, "О системе", 14, C.white, C.blue)

  local bar = taskbarLayout()
  fill(bar.x, bar.y, bar.w, 3, " ", C.white, C.taskbar)
  fill(bar.startX, bar.y, math.min(8, bar.w), 3, " ", C.white, C.taskbarButton)
  text(bar.startX + 1, bar.y + 1, "[ПУСК]", 7, C.white, C.taskbarButton)
  if bar.webX + 9 <= bar.x + bar.w - 1 then
    fill(bar.webX, bar.y, 10, 3, " ", C.white, state.app == "browser" and C.taskbarActive or C.taskbarButton)
    text(bar.webX + 1, bar.y + 1, "[WWW]", 8, C.white, state.app == "browser" and C.taskbarActive or C.taskbarButton)
  end
  if bar.powerX + 8 <= bar.x + bar.w - 1 then
    fill(bar.powerX, bar.y, 9, 3, " ", C.white, state.powerOpen and C.taskbarActive or C.taskbarButton)
    text(bar.powerX + 1, bar.y + 1, "[POWER]", 7, C.white, state.powerOpen and C.taskbarActive or C.taskbarButton)
  end
  text(sw - 7, bar.y + 1, os.date("%H:%M"), 5, C.white, C.taskbar)

  if state.startOpen then drawStartMenu() end
  if state.powerOpen then drawPowerMenu() end
end

local function htmlToText(html)
  html = html:gsub("<[sS][cC][rR][iI][pP][tT][^>]*>[%s%S]-</[sS][cC][rR][iI][pP][tT]%s*>", " ")
  html = html:gsub("<[sS][tT][yY][lL][eE][^>]*>[%s%S]-</[sS][tT][yY][lL][eE]%s*>", " ")
  html = html:gsub("<[bB][rR]%s*/?>", "\n")
  html = html:gsub("</[pP]%s*>", "\n\n")
  html = html:gsub("</[dD][iI][vV]%s*>", "\n")
  html = html:gsub("</[hH][1-6]%s*>", "\n\n")
  html = html:gsub("</[lL][iI]%s*>", "\n")
  html = html:gsub("<[tT][rR][^>]*>", "\n")
  html = html:gsub("</[tT][dD]%s*>", "  ")
  html = html:gsub("<[^>]->", " ")
  html = html:gsub("&nbsp;", " "):gsub("&amp;", "&"):gsub("&lt;", "<")
  html = html:gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&#39;", "'")
  html = html:gsub("&copy;", "(c)"):gsub("&mdash;", "-"):gsub("&ndash;", "-")
  html = html:gsub("&#(%d+);", function(n)
    local cp = tonumber(n)
    if cp and cp > 0 and cp <= 0x10FFFF then
      local ok, result = pcall(unicode.char, cp)
      if ok then return result end
    end
    return " "
  end)
  html = html:gsub("&#x([%da-fA-F]+);", function(n)
    local cp = tonumber(n, 16)
    if cp and cp > 0 and cp <= 0x10FFFF then
      local ok, result = pcall(unicode.char, cp)
      if ok then return result end
    end
    return " "
  end)
  html = html:gsub("\r", "")
  html = html:gsub("[ \t]+", " ")
  html = html:gsub(" *\n *", "\n")
  html = html:gsub("\n\n\n+", "\n\n")
  return html
end

local function wrapText(value, width)
  local lines = {}
  width = math.max(1, width)
  for raw in (value .. "\n"):gmatch("(.-)\n") do
    if raw == "" then
      lines[#lines + 1] = ""
    else
      local line = ""
      for word in raw:gmatch("%S+") do
        local candidate = line == "" and word or (line .. " " .. word)
        if unicode.len(candidate) <= width then
          line = candidate
        else
          if line ~= "" then lines[#lines + 1] = line end
          while unicode.len(word) > width do
            lines[#lines + 1] = unicode.sub(word, 1, width)
            word = unicode.sub(word, width + 1)
          end
          line = word
        end
      end
      lines[#lines + 1] = line
    end
  end
  return lines
end

local function normalizeURL(url)
  url = (url or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if url == "" then return nil end
  if not url:match("^https?://") then url = "https://" .. url end
  return url
end

local drawBrowser

local function loadPage(addToHistory)
  local url = normalizeURL(state.url)
  if not url then
    state.status = "Сначала введите адрес сайта"
    if drawBrowser then drawBrowser() end
    return
  end
  state.url = url
  if addToHistory ~= false then
    for i = #state.history, state.historyIndex + 1, -1 do state.history[i] = nil end
    state.history[#state.history + 1] = url
    state.historyIndex = #state.history
  end
  state.status = "Загрузка страницы..."
  state.pageTitle = url
  state.pageLines = { "Подключаюсь к сайту..." }
  state.scroll = 0
  if drawBrowser then drawBrowser() end

  if not internet then
    state.status = "Internet Card / библиотека internet не найдена"
    state.pageLines = {
      "OpenOS не обнаружил библиотеку internet.",
      "Подключите Internet Card и проверьте конфигурацию мода.",
    }
    if drawBrowser then drawBrowser() end
    return
  end

  local ok, body, truncated = pcall(function()
    local chunks, total = {}, 0
    local request = internet.request(url, nil, { ["User-Agent"] = "MineOS11-TextBrowser/1.1" })
    for chunk in request do
      if type(chunk) == "string" then
        local remaining = state.maxBody - total
        if remaining <= 0 then break end
        if #chunk > remaining then chunk = chunk:sub(1, remaining) end
        chunks[#chunks + 1] = chunk
        total = total + #chunk
      end
      if total >= state.maxBody then break end
    end
    return table.concat(chunks), total >= state.maxBody
  end)

  if not ok then
    state.status = "Не удалось загрузить страницу"
    state.pageLines = {
      tostring(body),
      "",
      "Проверьте Internet Card, настройку HTTP и адрес сайта.",
    }
  else
    local plain = htmlToText(body or "")
    state.pageLines = wrapText(plain, math.max(15, sw - 8))
    if #state.pageLines == 0 then state.pageLines = { "На странице не найден отображаемый текст." } end
    if truncated then state.pageLines[#state.pageLines + 1] = "[Ответ обрезан по лимиту 128 KiB.]" end
    state.status = "Загружено " .. tostring(#(body or "")) .. " байт"
  end
  if drawBrowser then drawBrowser() end
end

local function historyBack()
  if state.historyIndex > 1 then
    state.historyIndex = state.historyIndex - 1
    state.url = state.history[state.historyIndex]
    loadPage(false)
  else
    state.status = "Это первая страница истории"
    if drawBrowser then drawBrowser() end
  end
end

local function historyForward()
  if state.historyIndex < #state.history then
    state.historyIndex = state.historyIndex + 1
    state.url = state.history[state.historyIndex]
    loadPage(false)
  else
    state.status = "Вперёд перейти некуда"
    if drawBrowser then drawBrowser() end
  end
end

drawBrowser = function()
  sw, sh = gpu.getResolution()
  fill(1, 1, sw, sh, " ", C.white, C.blue)
  local x, y = 2, 2
  local w, h = math.max(20, sw - 2), math.max(10, sh - 4)
  frame(x, y, w, h, C.window)
  fill(x + 1, y + 1, w - 2, 1, " ", C.white, C.taskbar)
  text(x + 2, y + 1, "MineOS Browser  |  Текстовый режим", math.max(1, w - 12), C.white, C.taskbar)
  text(x + w - 5, y + 1, "[X]", 3, C.white, C.red)

  local toolbarY = y + 2
  fill(x + 1, toolbarY, w - 2, 2, " ", C.ink, C.pale)
  local backX, forwardX, refreshX = x + 2, x + 7, x + 12
  fill(backX, toolbarY, 4, 1, " ", C.ink, C.white)
  text(backX, toolbarY, "[<]", 4, C.ink, C.white)
  fill(forwardX, toolbarY, 4, 1, " ", C.ink, C.white)
  text(forwardX, toolbarY, "[>]", 4, C.ink, C.white)
  fill(refreshX, toolbarY, 4, 1, " ", C.ink, C.white)
  text(refreshX, toolbarY, "[R]", 4, C.ink, C.white)

  local goX = x + w - 11
  local fieldX = x + 17
  local fieldW = math.max(1, goX - fieldX - 1)
  fill(fieldX, toolbarY, fieldW, 1, " ", C.ink, C.white)
  local shownURL = state.url
  local urlLen = unicode.len(shownURL)
  if urlLen > fieldW - 2 then shownURL = unicode.sub(shownURL, urlLen - fieldW + 3) end
  text(fieldX + 1, toolbarY, shownURL, fieldW - 2, C.ink, C.white)
  fill(goX, toolbarY, 9, 1, " ", C.white, C.accent)
  text(goX, toolbarY, "[GO]", 9, C.white, C.accent)

  state.browserHit = {
    closeX = x + w - 5, closeY = y + 1,
    toolbarY = toolbarY,
    backX = backX, forwardX = forwardX, refreshX = refreshX,
    fieldX = fieldX, fieldEnd = goX - 1, goX = goX,
    contentTop = y + 5, contentBottom = y + h - 3,
  }

  fill(x + 1, y + 4, w - 2, 1, " ", C.ink, C.white)
  text(x + 2, y + 4, state.pageTitle, w - 4, C.ink, C.white)
  local contentY = y + 5
  local contentH = math.max(1, h - 7)
  fill(x + 1, contentY, w - 2, contentH, " ", C.ink, C.white)
  local visible = math.max(1, contentH - 1)
  for i = 1, visible do
    local line = state.pageLines[state.scroll + i]
    if not line then break end
    text(x + 2, contentY + i - 1, line, w - 4, C.ink, C.white)
  end
  fill(x + 1, y + h - 2, w - 2, 1, " ", C.ink, C.pale)
  text(x + 2, y + h - 2, state.status, w - 4, C.muted, C.pale)
  text(2, sh, "Esc: рабочий стол | Enter: перейти | ↑/↓: прокрутка", sw - 3, C.white, C.blue)
end

local function openBrowser()
  state.app = "browser"
  state.startOpen = false
  state.powerOpen = false
  drawBrowser()
end

local function openAbout()
  state.app = "about"
  state.startOpen = false
  state.powerOpen = false
  drawDesktop()
  local w, h = math.min(48, sw - 4), math.min(15, sh - 5)
  local x, y = math.floor((sw - w) / 2) + 1, math.floor((sh - h) / 2) + 1
  frame(x, y, w, h, C.window)
  fill(x + 1, y + 1, w - 2, 2, " ", C.white, C.accent)
  text(x + 2, y + 1, "О системе MineOS 11", w - 4, C.white, C.accent)
  text(x + 2, y + 4, "Рабочий стол и текстовый HTTP(S)-браузер для OpenOS.", w - 4, C.ink, C.window)
  local address = "unknown"
  pcall(function() address = computer.address():sub(1, 8) end)
  text(x + 2, y + 6, "Компьютер: " .. address, w - 4, C.ink, C.window)
  local mOK, total = pcall(computer.totalMemory)
  local fOK, free = pcall(computer.freeMemory)
  if mOK and fOK then
    text(x + 2, y + 8, string.format("Lua RAM: %.1f / %.1f KiB занято", (total - free) / 1024, total / 1024), w - 4, C.ink, C.window)
  end
  text(x + 2, y + 10, internet and "Internet API доступен" or "Internet API не найден", w - 4, internet and C.green or C.red, C.window)
  text(x + 2, y + h - 2, "Нажмите экран или клавишу для возврата", w - 4, C.muted, C.window)
end

local function powerAction(reboot)
  fill(1, 1, sw, sh, " ", C.white, C.taskbar)
  text(3, 3, reboot and "MineOS: перезагрузка компьютера..." or "MineOS: выключение компьютера...", sw - 5, C.white, C.taskbar)
  computer.shutdown(reboot)
end

local function openPowerMenu()
  state.startOpen = false
  state.powerOpen = true
  drawDesktop()
end

local function handleBrowserClick(x, y)
  local hit = state.browserHit
  if y == hit.closeY and x >= hit.closeX then
    state.app = "desktop"
    drawDesktop()
    return
  end
  if y == hit.toolbarY then
    if x >= hit.backX and x <= hit.backX + 3 then historyBack(); return end
    if x >= hit.forwardX and x <= hit.forwardX + 3 then historyForward(); return end
    if x >= hit.refreshX and x <= hit.refreshX + 3 then loadPage(false); return end
    if x >= hit.goX and x <= hit.goX + 8 then loadPage(true); return end
    if x >= hit.fieldX and x <= hit.fieldEnd then
      state.url = ""
      state.status = "Введите адрес и нажмите Enter"
      drawBrowser()
      return
    end
  end
end

local function handleDesktopClick(x, y)
  local bar = taskbarLayout()
  if state.powerOpen then
    local px, py, pw = powerLayout()
    if x >= px and x <= px + pw and y >= py and y <= py + 9 then
      if y >= py + 3 and y <= py + 4 then powerAction(false); return end
      if y >= py + 5 and y <= py + 6 then powerAction(true); return end
      state.powerOpen = false
      drawDesktop()
      return
    end
    state.powerOpen = false
  end

  if state.startOpen then
    local mx, my, mw, mh = menuLayout()
    if x >= mx and x <= mx + mw and y >= my and y <= my + mh then
      if y >= my + 3 and y <= my + 4 then openBrowser(); return end
      if y >= my + 5 and y <= my + 6 then openAbout(); return end
      if y >= my + 7 and y <= my + 9 then openPowerMenu(); return end
    end
    state.startOpen = false
  end

  if y >= bar.y and y <= bar.y + 2 then
    if x >= bar.startX and x <= bar.startX + 7 then
      state.startOpen = not state.startOpen
      state.powerOpen = false
      drawDesktop()
      return
    end
    if x >= bar.webX and x <= bar.webX + 9 then openBrowser(); return end
    if x >= bar.powerX and x <= bar.powerX + 8 then openPowerMenu(); return end
  end
  if x >= 2 and x <= 18 and y >= 6 and y <= 10 then openBrowser(); return end
  if x >= 2 and x <= 18 and y >= 12 and y <= 16 then openAbout(); return end
  drawDesktop()
end

local function handleClick(x, y)
  if state.app == "browser" then handleBrowserClick(x, y); return end
  if state.app == "about" then state.app = "desktop"; drawDesktop(); return end
  handleDesktopClick(x, y)
end

local function handleKey(char, code)
  if state.app == "about" then
    state.app = "desktop"
    drawDesktop()
    return
  end
  if code == 1 then
    if state.app ~= "desktop" then state.app = "desktop"; drawDesktop()
    elseif state.startOpen or state.powerOpen then state.startOpen = false; state.powerOpen = false; drawDesktop() end
    return
  end
  if state.app == "browser" then
    if code == 28 then loadPage(true); return end
    if code == 14 then
      state.url = unicode.sub(state.url, 1, math.max(0, unicode.len(state.url) - 1))
      drawBrowser()
      return
    end
    if code == 200 then state.scroll = math.max(0, state.scroll - 1); drawBrowser(); return end
    if code == 208 then state.scroll = math.min(math.max(0, #state.pageLines - 1), state.scroll + 1); drawBrowser(); return end
    if char and char > 0 then
      local ok, ch = pcall(unicode.char, char)
      if ok and ch and ch ~= "\n" and ch ~= "\r" then
        state.url = state.url .. ch
        drawBrowser()
      end
    end
    return
  end
  if state.app == "desktop" and (char == 13 or code == 28) then openBrowser() end
end

local function main()
  drawDesktop()
  while true do
    local e = { event.pull() }
    if e[1] == "interrupted" then break end
    if e[1] == "touch" then
      handleClick(tonumber(e[3]) or 0, tonumber(e[4]) or 0)
    elseif e[1] == "key_down" then
      handleKey(tonumber(e[3]) or 0, tonumber(e[4]) or 0)
    end
  end
end

local ok, err = xpcall(main, debug.traceback)
pcall(function() fill(1, 1, sw, sh, " ", C.ink, C.window) end)
if not ok then error(err) end
