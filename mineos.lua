-- MineOS 11: desktop shell and lightweight text web browser for OpenComputers.
-- Tested conceptually against OpenComputers 1.7.x APIs.
-- Requires: screen + GPU; Internet Card for web browsing.
-- Start from the OC shell with: lua /home/mineos.lua

local component = require("component")
local event = require("event")
local unicode = require("unicode")
local computer = require("computer")

local gpu = component.gpu
if not gpu then error("MineOS 11: GPU not found") end

local internet
local internetOK, internetLib = pcall(require, "internet")
if internetOK then internet = internetLib end

pcall(function()
  local mw, mh = gpu.maxResolution()
  if mw and mh then gpu.setResolution(mw, mh) end
end)
pcall(function() gpu.setDepth(8) end)

local sw, sh = gpu.getResolution()
local C = {
  desktop = 0x173B73,
  desktop2 = 0x2363A5,
  panel = 0x17253B,
  panel2 = 0x24364F,
  window = 0xF2F5F9,
  white = 0xFFFFFF,
  ink = 0x172033,
  muted = 0x68758A,
  accent = 0x2878D0,
  accent2 = 0xDCEBFA,
  border = 0xC7D3E2,
  red = 0xD94A4A,
  green = 0x16845B,
}

local state = {
  app = "desktop",
  startOpen = false,
  url = "https://example.com",
  pageTitle = "Добро пожаловать",
  pageLines = {
    "Браузер MineOS 11 готов.",
    "",
    "Введите адрес сайта в строку сверху и нажмите Enter или кнопку Перейти.",
    "",
    "Для доступа в интернет нужна Internet Card, а HTTP должен быть включён в настройках OpenComputers.",
    "",
    "Это текстовый браузер: он загружает HTTP(S)-страницы, но не исполняет JavaScript и не отображает CSS/изображения.",
  },
  scroll = 0,
  status = "Готово",
  maxBody = 131072,
}

local function color(fg, bg)
  gpu.setForeground(fg or C.ink)
  gpu.setBackground(bg or C.window)
end

local function fill(x, y, w, h, ch, fg, bg)
  if w <= 0 or h <= 0 then return end
  color(fg, bg)
  gpu.fill(x, y, w, h, ch or " ")
end

local function text(x, y, value, maxw, fg, bg)
  if y < 1 or y > sh or x > sw then return end
  value = tostring(value or "")
  if maxw then value = unicode.sub(value, 1, math.max(0, maxw)) end
  if x + unicode.len(value) - 1 > sw then
    value = unicode.sub(value, 1, math.max(0, sw - x + 1))
  end
  if value == "" then return end
  color(fg or C.ink, bg or C.window)
  gpu.set(x, y, value)
end

local function box(x, y, w, h, bg)
  fill(x, y, w, h, " ", C.ink, bg)
  if w >= 2 and h >= 2 then
    fill(x, y, w, 1, "-", C.ink, bg)
    fill(x, y + h - 1, w, 1, "-", C.ink, bg)
    fill(x, y, 1, h, "|", C.ink, bg)
    fill(x + w - 1, y, 1, h, "|", C.ink, bg)
    text(x, y, "+", 1, C.ink, bg)
    text(x + w - 1, y, "+", 1, C.ink, bg)
    text(x, y + h - 1, "+", 1, C.ink, bg)
    text(x + w - 1, y + h - 1, "+", 1, C.ink, bg)
  end
end

local function taskbarY()
  return math.max(1, sh - 2)
end

local function desktopLayout()
  local barY = taskbarY()
  local barW = math.min(sw, math.max(22, math.floor(sw * 0.48)))
  local barX = math.floor((sw - barW) / 2) + 1
  return barX, barY, barW
end

local function drawDesktop()
  sw, sh = gpu.getResolution()
  fill(1, 1, sw, sh, " ", C.white, C.desktop)
  -- A simple two-tone Windows-inspired wallpaper.
  fill(1, math.floor(sh * 0.58), sw, sh - math.floor(sh * 0.58) + 1, " ", C.white, C.desktop2)
  text(3, 2, "MineOS 11", 30, C.white, C.desktop)
  text(3, 3, "Рабочий стол", 30, 0xD7E8FB, C.desktop)

  local iconX, iconY = 4, 6
  text(iconX, iconY, "[WWW]", 10, C.white, C.desktop)
  text(iconX, iconY + 1, "Браузер", 14, C.white, C.desktop)
  text(iconX, iconY + 4, "[ i ]", 10, C.white, C.desktop)
  text(iconX, iconY + 5, "О системе", 14, C.white, C.desktop)

  local bx, by, bw = desktopLayout()
  fill(bx, by, bw, 3, " ", C.white, C.panel)
  local startW = math.min(10, bw)
  fill(bx, by, startW, 3, " ", C.white, C.panel2)
  text(bx + 2, by + 1, "[WIN]", startW - 2, C.white, C.panel2)
  if bw > startW + 5 then
    text(bx + startW + 2, by + 1, "MineOS 11  |  Браузер  |  Питание", bw - startW - 3, C.white, C.panel)
  end
  text(sw - 10, by + 1, "" .. os.date("%H:%M"), 8, C.white, C.panel)

  if state.startOpen then
    local menuW = math.min(34, sw - 4)
    local menuH = math.min(12, sh - 5)
    local mx = math.floor((sw - menuW) / 2) + 1
    local my = math.max(1, by - menuH)
    box(mx, my, menuW, menuH, C.window)
    fill(mx + 1, my + 1, menuW - 2, 2, " ", C.white, C.accent)
    text(mx + 2, my + 1, "Пуск  |  MineOS 11", menuW - 4, C.white, C.accent)
    text(mx + 2, my + 4, "Браузер", menuW - 4, C.ink, C.window)
    text(mx + 2, my + 6, "О системе", menuW - 4, C.ink, C.window)
    text(mx + 2, my + 9, "Нажмите пункт, чтобы открыть", menuW - 4, C.muted, C.window)
  end
end

local function htmlToText(html)
  html = html:gsub("<script[%s%S]-</script%s*>", " ")
  html = html:gsub("<style[%s%S]-</style%s*>", " ")
  html = html:gsub("<[bB][rR]%s*/?>", "\n")
  html = html:gsub("</[pP]%s*>", "\n\n")
  html = html:gsub("</[dD][iI][vV]%s*>", "\n")
  html = html:gsub("</[hH][1-6]%s*>", "\n\n")
  html = html:gsub("</[lL][iI]%s*>", "\n")
  html = html:gsub("<[^>]->", " ")
  html = html:gsub("&nbsp;", " "):gsub("&amp;", "&"):gsub("&lt;", "<")
  html = html:gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&#39;", "'")
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

local function loadPage()
  local url = normalizeURL(state.url)
  if not url then state.status = "Введите адрес сайта"; return end
  state.url = url
  state.status = "Загрузка..."
  state.pageTitle = url
  state.pageLines = { "Загружаю страницу..." }
  state.scroll = 0
  drawBrowser()

  if not internet then
    state.status = "Нет библиотеки internet"
    state.pageLines = { "Не найдена библиотека internet.", "Проверьте наличие Internet Card и поддержку интернета в сборке OpenComputers." }
    return
  end

  local ok, body, truncated = pcall(function()
    local chunks = {}
    local total = 0
    local iterator = internet.request(url, nil, { ["User-Agent"] = "MineOS11-TextBrowser/1.0" })
    for chunk in iterator do
      if type(chunk) == "string" then
        local remain = state.maxBody - total
        if remain <= 0 then break end
        if #chunk > remain then chunk = chunk:sub(1, remain) end
        chunks[#chunks + 1] = chunk
        total = total + #chunk
      end
      if total >= state.maxBody then break end
    end
    return table.concat(chunks), total >= state.maxBody
  end)

  if not ok then
    state.status = "Ошибка загрузки"
    state.pageLines = {
      "Не удалось загрузить страницу:",
      tostring(body),
      "",
      "Проверьте Internet Card, HTTP в конфигурации мода и URL.",
    }
    return
  end

  local plain = htmlToText(body or "")
  local width = math.max(15, sw - 10)
  state.pageLines = wrapText(plain, width)
  if #state.pageLines == 0 then state.pageLines = { "Страница не содержит отображаемого текста." } end
  if truncated then state.pageLines[#state.pageLines + 1] = "[Текст обрезан: достигнут лимит загрузки браузера.]" end
  state.status = "Загружено: " .. tostring(#(body or "")) .. " байт"
end

function drawBrowser()
  sw, sh = gpu.getResolution()
  fill(1, 1, sw, sh, " ", C.ink, C.desktop)
  local x, y = 2, 2
  local w, h = math.max(20, sw - 2), math.max(10, sh - 4)
  box(x, y, w, h, C.window)
  fill(x + 1, y + 1, w - 2, 1, " ", C.white, C.panel)
  text(x + 2, y + 1, "MineOS Browser", math.max(1, w - 12), C.white, C.panel)
  text(x + w - 5, y + 1, "[X]", 3, C.white, C.red)

  fill(x + 1, y + 2, w - 2, 2, " ", C.ink, 0xE7EDF5)
  text(x + 2, y + 2, "<-  ->  Обновить", 20, C.ink, 0xE7EDF5)
  local fieldX = x + 22
  local fieldW = math.max(1, w - 36)
  fill(fieldX, y + 2, fieldW, 1, " ", C.ink, C.white)
  local visibleURL = state.url
  local urlLen = unicode.len(visibleURL)
  if urlLen > fieldW then visibleURL = unicode.sub(visibleURL, urlLen - fieldW + 1) end
  text(fieldX + 1, y + 2, visibleURL, fieldW - 2, C.ink, C.white)
  text(x + w - 12, y + 2, "Перейти", 9, C.white, C.accent)

  fill(x + 1, y + 4, w - 2, 1, " ", C.ink, C.white)
  text(x + 2, y + 4, state.pageTitle, w - 4, C.ink, C.white)
  local contentY = y + 5
  local contentH = math.max(1, h - 7)
  fill(x + 1, contentY, w - 2, contentH, " ", C.ink, C.white)
  local visible = contentH - 1
  for i = 1, visible do
    local line = state.pageLines[state.scroll + i]
    if not line then break end
    text(x + 2, contentY + i - 1, line, w - 4, C.ink, C.white)
  end
  fill(x + 1, y + h - 2, w - 2, 1, " ", C.ink, 0xE7EDF5)
  text(x + 2, y + h - 2, state.status, w - 4, C.muted, 0xE7EDF5)
  text(2, sh, "Esc: рабочий стол   Enter: открыть адрес   ↑/↓: прокрутка", sw - 3, C.white, C.desktop)
end

local function drawAbout()
  sw, sh = gpu.getResolution()
  drawDesktop()
  local w, h = math.min(48, sw - 4), math.min(14, sh - 5)
  local x, y = math.floor((sw - w) / 2) + 1, math.floor((sh - h) / 2) + 1
  box(x, y, w, h, C.window)
  fill(x + 1, y + 1, w - 2, 2, " ", C.white, C.accent)
  text(x + 2, y + 1, "О системе MineOS 11", w - 4, C.white, C.accent)
  text(x + 2, y + 4, "Оболочка рабочего стола для OpenComputers.", w - 4, C.ink, C.window)
  text(x + 2, y + 6, "Компьютер: " .. tostring(computer.address():sub(1, 8)), w - 4, C.ink, C.window)
  local memOK, totalMem = pcall(computer.totalMemory)
  local freeOK, freeMem = pcall(computer.freeMemory)
  if memOK and freeOK then
    text(x + 2, y + 8, string.format("Память Lua: %.1f / %.1f KiB занято", (totalMem - freeMem) / 1024, totalMem / 1024), w - 4, C.ink, C.window)
  else
    text(x + 2, y + 8, "Память: API недоступен", w - 4, C.ink, C.window)
  end
  text(x + 2, y + 10, internet and "Интернет-библиотека найдена" or "Интернет-библиотека не найдена", w - 4, internet and C.green or C.red, C.window)
  text(x + 2, y + h - 2, "Нажмите любую клавишу или экран для возврата", w - 4, C.muted, C.window)
end

local function openBrowser()
  state.app = "browser"
  drawBrowser()
end

local function openAbout()
  state.app = "about"
  drawAbout()
end

local function launchByClick(x, y)
  if state.app == "browser" then
    local winX, winY, winW = 2, 2, math.max(20, sw - 2)
    if y == winY + 1 and x >= winX + winW - 6 then
      state.app = "desktop"
      drawDesktop()
      return
    end
    local fieldX, fieldY = winX + 22, winY + 2
    if y == fieldY and x >= fieldX and x < winX + winW - 13 then
      state.url = ""
      state.status = "Введите адрес и нажмите Enter"
      drawBrowser()
      return
    end
    if y == fieldY and x >= winX + winW - 12 then loadPage(); drawBrowser(); return end
    if y == winY + 2 and x < winX + 20 then loadPage(); drawBrowser(); return end
    return
  end

  local bx, by, bw = desktopLayout()
  if state.startOpen then
    local menuW = math.min(34, sw - 4)
    local menuH = math.min(12, sh - 5)
    local mx = math.floor((sw - menuW) / 2) + 1
    local my = math.max(1, by - menuH)
    if x >= mx and x <= mx + menuW and y >= my and y <= my + menuH then
      if y <= my + 5 then state.startOpen = false; openBrowser(); return end
      if y <= my + 7 then state.startOpen = false; openAbout(); return end
    end
    state.startOpen = false
  end
  if y >= by and x >= bx and x < bx + math.min(10, bw) then
    state.startOpen = not state.startOpen
    drawDesktop()
    return
  end
  if x >= 2 and x <= 18 and y >= 6 and y <= 8 then openBrowser(); return end
  if x >= 2 and x <= 18 and y >= 10 and y <= 12 then openAbout(); return end
  drawDesktop()
end

local function handleKey(char, code)
  if state.app == "about" then
    state.app = "desktop"
    drawDesktop()
    return
  end
  if code == 1 then -- Escape
    if state.app ~= "desktop" then state.app = "desktop"; drawDesktop()
    elseif state.startOpen then state.startOpen = false; drawDesktop() end
    return
  end
  if state.app == "browser" then
    if code == 28 then loadPage(); drawBrowser(); return end -- Enter
    if code == 14 then -- Backspace
      state.url = unicode.sub(state.url, 1, math.max(0, unicode.len(state.url) - 1))
      drawBrowser(); return
    end
    if code == 200 then state.scroll = math.max(0, state.scroll - 1); drawBrowser(); return end
    if code == 208 then state.scroll = math.min(math.max(0, #state.pageLines - 1), state.scroll + 1); drawBrowser(); return end
    if char and char > 0 then
      local ok, ch = pcall(unicode.char, char)
      if ok and ch and ch ~= "\n" and ch ~= "\r" then state.url = state.url .. ch; drawBrowser() end
    end
    return
  end
  if state.app == "desktop" then
    if state.startOpen then
      state.startOpen = false
      drawDesktop()
    elseif char == 13 or code == 28 then
      openBrowser()
    end
  end
end

local function main()
  drawDesktop()
  while true do
    local e = { event.pull() }
    if e[1] == "interrupted" then break end
    if e[1] == "touch" then
      launchByClick(tonumber(e[3]) or 0, tonumber(e[4]) or 0)
    elseif e[1] == "key_down" then
      handleKey(tonumber(e[3]) or 0, tonumber(e[4]) or 0)
    end
  end
end

local ok, err = xpcall(main, debug.traceback)
pcall(function() fill(1, 1, sw, sh, " ", C.ink, C.window) end)
if not ok then error(err) end
