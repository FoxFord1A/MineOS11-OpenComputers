# MineOS 11 для OpenComputers

Небольшая оболочка рабочего стола в стиле Windows 11 для OpenComputers и текстовый браузер с HTTP(S)-загрузкой. Установка запускается из OpenOS.

## Возможности и ограничения

- Рабочий стол, панель задач, меню «Пуск», окно «О системе».
- Браузер скачивает страницы через Internet Card и показывает извлечённый текст.
- Это **не полноценный современный браузер**: JavaScript, CSS и изображения не исполняются/не отображаются.
- Для сайтов нужна Internet Card, а HTTP-запросы должны быть разрешены конфигурацией OpenComputers.

## Установка с GitHub из OpenOS

Репозиторий для проекта: `https://github.com/FoxFord1A/MineOS11-OpenComputers`.

Когда репозиторий публичный, в OpenOS выполните:

```sh
wget -f https://raw.githubusercontent.com/FoxFord1A/MineOS11-OpenComputers/main/mineos-install.lua /home/mineos-install.lua
lua /home/mineos-install.lua
```

Установщик скачает `mineos.lua` в `/home/mineos.lua`; существующую версию перед заменой сохранит как `/home/mineos.lua.bak` (или с номером, если такое имя занято). Запуск оболочки:

```sh
lua /home/mineos.lua
```

## Ручная установка без установщика

```sh
wget -f https://raw.githubusercontent.com/FoxFord1A/MineOS11-OpenComputers/main/mineos.lua /home/mineos.lua
lua /home/mineos.lua
```

## Опубликовать проект в GitHub

Чтобы OpenOS мог скачать `raw.githubusercontent.com` без учётных данных, репозиторий должен быть **публичным**. Если загружаете файлы вручную:

1. На GitHub нажмите **New repository** и создайте `MineOS11-OpenComputers`.
2. Выберите **Public**, если хотите, чтобы установщик работал из OpenOS без токена.
3. Добавьте `mineos.lua`, `mineos-install.lua` и этот README в ветку `main`.
4. Проверьте в браузере, что открывается `https://raw.githubusercontent.com/FoxFord1A/MineOS11-OpenComputers/main/mineos-install.lua`.
5. Выполните команды установки выше в OpenOS.

Для локальной публикации с установленным Git и GitHub CLI:

```sh
git init -b main
git add mineos.lua mineos-install.lua README.md
git commit -m "Add MineOS 11 desktop and OpenOS installer"
gh repo create FoxFord1A/MineOS11-OpenComputers --public --source=. --remote=origin --push
```

**Важно:** публикация делает код доступным всем. Не помещайте в репозиторий пароли, токены и личные данные. Если репозиторий приватный, OpenOS не сможет скачать файлы напрямую без отдельной авторизации.
