# Nidal Books

مكتبة كتب وPDF شخصية بتصميم «ورق وحبر». كل البيانات محلية على الهاتف: SQLite وملفات وإعدادات، بلا خادم ولا حساب سحابي.

Personal book and PDF library for Android (Flutter, Arabic RTL). All data stays on the device.

## What works offline
- Import PDF / TXT files, library list and grid, categories, shelves (folders), edit metadata
- Reader: text mode with font size and light/dark themes, page slider, in-book search, bookmarks, highlights, notes, original PDF view, text-to-speech (device voice)
- Cross-book search (titles, authors, inside texts), notes export (Markdown), reading stats and weekly goal
- Local backup/restore (JSON of metadata, notes, shelves; book files are not included), reading-list sharing as text
- Optional PIN lock, library management (storage, duplicates, missing files)

## Needs internet
- **Nidal AI** (chat, summary, quiz, translation). No backend of ours: the app calls an OpenAI-compatible endpoint you configure (base URL, model, API key) from the phone. The key is stored only on the device. Without it, simple on-device helpers remain (extractive summary, flashcards from your highlights).

## Not included (needs a server)
Cloud sync across devices and live sharing between users. Backup files and shared lists replace them.

## Build
`flutter pub get && flutter build apk --release`. The GitHub Actions workflow `Build APK` builds split-per-ABI APKs.

Design preview: "Nidal Books - ورق وحبر". Sample text is a short public-domain excerpt of Ibn Khaldun's Muqaddima.
