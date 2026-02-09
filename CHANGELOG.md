# Changelog

All notable changes to the AwiOS Visual Novel Engine are documented here.

## [1.0.0] - 2025-02-09

### First release

**AwiOS** is a visual novel engine with a smartphone-style UI (Python + Flet). This release includes:

#### Apps
- **Messages** – Chat-style dialogues with auto-advance (speed controlled in Settings), choices, stats (affection, trust, corruption, points), and media (images, GIFs, videos). Media seen in chats is saved to the Gallery.
- **Gallery** – Shows images from `assets/images/` (wallpaper set) and media unlocked from Messages. Tap to view full-screen with prev/next.
- **Settings** – Message display speed, auto-save, notifications toggle, language, restore defaults, and credits (Awi-24 on GitHub).

#### Features
- **Dialogue system** – JSON-based dialogues with messages, choices, effects, conditions, and media (image, gif, video).
- **Backgrounds** – Wallpaper from `assets/images/`; change in Gallery when viewing an image (optional).
- **Save/Load** – Auto-save of conversation state and settings.
- **i18n** – Locales in `locales/` (en_US, pt_BR).
- **Lock screen** – Notifications; tap to unlock and open home screen with app grid.

#### Technical
- **Engine** – `MobileEngine` with app registration, state, settings, and background manager.
- **Apps** – Extend `App` from `src.core.app_base`; implement `render(page)` and optional `on_open` / `on_close`.
- **Dialogue parser** – Loads JSON, resolves nodes, choices, conditions, and media.

#### Removed for v1.0
- Music app and audio playback (images and videos only).
- Rollback/Skip UI in Messages (engine APIs remain for future use).

---

Format based on [Keep a Changelog](https://keepachangelog.com/).
