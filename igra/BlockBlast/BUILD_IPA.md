# GlassAlarm — как собрать IPA (Windows + GitHub Actions)

> Важно: iOS-проект **не компилируется локально на Windows**. Сборка идет удаленно на macOS через GitHub Actions.

## Что нужно

- Windows
- Git
- GitHub-репозиторий с проектом
- `builder.exe` в корне проекта

Папка проекта:

```text
outputs/GlassAlarm
```

---

## Быстрая сборка unsigned IPA (без сертификата)

### 1) Инициализация builder (один раз)

```powershell
.\builder.exe init -p GlassAlarm --scheme GlassAlarm
```

Это создаст:

- `.github/workflows/ios-build.yml`
- `builder.json`

### 2) Закоммитить и запушить workflow/config

```powershell
git add .github/workflows/ios-build.yml builder.json
git commit -m "add builder config for unsigned ipa builds"
git push origin main
```

### 3) Авторизация builder в GitHub (один раз)

```powershell
.\builder.exe auth github
```

Открой ссылку из консоли, введи code, подтверди доступ.

### 4) Запуск сборки unsigned IPA

```powershell
.\builder.exe ios build --unsigned -o dist
```

После успешной сборки файл будет в:

```text
dist/GlassAlarm-<build-id>.ipa
```

Пример:

```text
dist/GlassAlarm-2ec680d6.ipa
```

---

## Где лежит IPA в этой сборке

```text
C:\Users\sivma\Documents\Codex\2026-05-31\build-macos-apps-plugin-build-macos\outputs\GlassAlarm\dist\GlassAlarm-2ec680d6.ipa
```

---

## Установка unsigned IPA на iPhone

Unsigned IPA не ставится «как есть» через App Store.
Используй один из вариантов:

- AltStore
- Sideloadly
- TrollStore (если устройство поддерживает)

---

## Если нужен подписанный IPA (signed)

Нужны:

- `.p12` сертификат
- `.mobileprovision` профиль

Настройка:

```powershell
.\builder.exe signing setup -c path\to\cert.p12 -p path\to\profile.mobileprovision
```

Сборка:

```powershell
.\builder.exe ios build -o dist
```

(без `--unsigned`)

---

## Частые проблемы

### `failed to trigger workflow: status 404`

Обычно значит:

- workflow еще не запушен в GitHub,
- или нет авторизации `builder auth github`,
- или нет прав к репозиторию.

### Сборка прошла, но артефакт не скачался

Проверь, что в `.github/workflows/ios-build.yml` пути упаковки IPA корректны относительно корня репозитория.

---

## Полезные команды

```powershell
# статус git
git status --short --branch

# пересборка unsigned
.\builder.exe ios build --unsigned -o dist

# help
.\builder.exe --help
.\builder.exe ios --help
.\builder.exe signing --help
```
