# AwiOS Engine

> **A Lightweight, Script-to-Scene Narrative Engine for Phone Simulators.**

AwiOS is a Flutter-based narrative engine that runs inside a fictional phone OS. Write stories in the `.awi` scripting language—no code required—and watch them unfold as chat conversations, choices, system notifications, and gallery unlocks.

---

## Key Features

| Feature | Description |
|---------|-------------|
| **`.awi` Scripting Language** | Declarative, writer-friendly format. Define characters, dialogue, choices, and system events in plain text. |
| **System-Wide Notifications** | Trigger toasts, push notifications, and app updates from script events. |
| **Integrated Gallery & Social Media** | Unlock photos in the gallery and posts in InstaHub (Instagram-style feed) via script commands. |
| **Samsung-Style Navigation Bar** | Dock with app icons (Messages, InstaHub, Gallery, Settings) for a realistic phone simulator feel. |

---

## How to Run

```bash
flutter pub get
dart run tool/generate_stories_manifest.dart   # after adding/renaming scripts
flutter run
```

Open **Messages** → **Interactive Guide** to experience the interactive tutorial.

---

## How to Use (For Writers)

You don't need to write code. Create `.awi` files in `assets/scripts/` and the engine will load them automatically.

### 1. Run the Interactive Guide

Open **Messages** and tap **Interactive Guide** (main.awi). A character walks you through dialogue, choices, notifications, and gallery unlocks with live examples.

### 2. Use the Template as Reference

`template.awi` documents every keyword and syntax. Copy it when writing your own scripts—it's a reference, not a runnable tutorial.

### 3. Story Naming Convention

```
{story_id}_{chapter:02d}.awi
```

| Part | Description | Example |
|------|-------------|---------|
| `story_id` | Unique identifier. Lowercase, snake_case | `tutorial_awi`, `my_story_v2` |
| `chapter` | Zero-padded 2-digit chapter number | `01`, `02`, `12` |

**Examples:** `tutorial_awi_01.awi`, `my_story_01.awi`, `my_story_02.awi`

**Rules:**
- Chapters are sorted by number; `_01` is always first.
- All files sharing the same `story_id` belong to the same story.
- Version in ID if needed: `tutorial_awi_v2_01.awi` → story_id = `tutorial_awi_v2`.

### 4. Structure Your Story

```yaml
SETTINGS
  id: my_chapter_01
  story_name: My Story
  avatar: assets/images/tulip.png
  preview: Tap to start!

CHARACTERS
  A: Assistant (#9C27B0) [assets/images/tulip.png]
  [Player] P: You (#2196F3) [assets/images/sunset_sky.png]
```

- `[Player]` marks the player character—their messages appear on the **right**.
- Other characters appear on the **left**.

### 5. Write Dialogue

```yaml
[start]
  type: chat
  A: Hello! Welcome to the story.
  P: Hi! What happens next?
  A: You'll see choices, images, and system events.
  next: choices
```

### 6. Add Choices

```yaml
[choices]
  type: choice
  A: What do you want to explore?
  > Notifications -> path_notify {RECORD_PATH: path_notify}
  > Gallery -> path_gallery {RECORD_PATH: path_gallery}
```

### 7. Use System Commands

```yaml
[path_notify]
  type: chat
  system: trigger(app="instahub", action="post", id="p_tulip")
  system: toast(title="InstaHub", body="New post!")
  system: notify(title="AwiOS", body="Post unlocked.", app="messages")
  A: Check InstaHub to see the new post!
  next: end

[path_gallery]
  type: chat
  system: unlock(app="gallery", id="assets/images/sunset_sky.png")
  unlock_gallery: assets/images/mountain_snow.png
  A: Two photos added to your gallery!
  next: end
```

### 8. Regenerate the Manifest

After adding or renaming scripts:

```bash
dart run tool/generate_stories_manifest.dart
```

---

## Complete .awi Reference

### How .awi Works

1. The engine loads the script (blocks `SETTINGS`, `THREADS`, `CHARACTERS`, `[label]`).
2. Flow starts at `[start]` or at `entry_point` defined in SETTINGS.
3. Each line `ID: Text` becomes a chat message; the player advances by tapping.
4. In `type: choice`, options are shown and the script waits for a choice.
5. `system:` executes commands silently (no bubbles) and integrates with apps.
6. `trigger:` without `next:` pauses until the player opens the indicated chat.
7. `next_chapter` ends the chapter and offers the transition.

### Data Model

| Type | Example | Use |
|------|---------|-----|
| **Variables** | `points`, `trust`, `task_done` | Numeric or boolean in choices and conditions |
| **Flags** | `met_alice`, `talked_to_sammy` | Boolean, tested in `condition` and `required_flag` |
| **History** | `history.chapter_01` | Path saved with `RECORD_PATH` for bridge between chapters |
| **Globals** | `global.romance_points` | Persist across chapters |

### Main Blocks

| Block | Where | Description |
|-------|-------|-------------|
| `SETTINGS` | Top | Chapter metadata (id, next_chapter, entry_point, etc.) |
| `THREADS` | After SETTINGS | Chat IDs for `trigger:` and `return_to:` |
| `CHARACTERS` | After THREADS | Characters, colors, avatars |
| `[label]` | Anywhere | Dialogue or choice block |

### SETTINGS Keys

| Key | Type | Description |
|-----|------|-------------|
| `id` | string | Chapter ID (used in `history.<id>`) |
| `next_chapter` | string | Next chapter when finished |
| `title` | string | Title (optional) |
| `entry_point` | list | Conditional start rules |
| `dependency` | string | Condition to start (e.g. `trust > 5`) |
| `required_flag` | string | Required flag to start |
| `story_name` | string | Name in chat list (first chapter only) |
| `avatar` | string | Default avatar path |
| `preview` | string | Preview text in chat list |

### THREADS Format

```
id: name | start_label | character_id (optional)
```

- **id**: Used in `trigger: id` and `return_to: id`
- **name**: Display name in chat list
- **start_label**: Block where the conversation starts
- **character_id**: Character ID for 1-on-1 (e.g. `S` for Sammy)

### CHARACTERS Format

```
[Player]? ID: Name (#RRGGBB) [avatar]
```

- `[Player]` — player character (messages on the right)
- `ID` — 1–3 characters (A, B, M, Y, P, S)
- `#RRGGBB` — bubble color (hex)
- `[avatar]` — image path (optional)

### Dialogue Block Directives

| Directive | Description |
|-----------|-------------|
| `ID: Text` | Character line |
| `next: label` | Next block |
| `delay: 2.0` | Delay in seconds before next message |
| `image: path` | Image in bubble (unlocks in gallery) |
| `condition: expr` | Condition to enter block |
| `trigger: id` | Unlocks chat; without `next:` pauses until player opens |
| `return_to: id` | Returns to indicated chat when done |
| `unlock_gallery: path` | Unlocks image in gallery |
| `type: chat` | Default type (can omit) |
| `type: choice` | Choice block |
| `next_chapter: id` | Ends chapter and transitions |

### system: Commands

Format: `system: command(param="value", ...)`

| Command | Parameters | Description |
|---------|------------|-------------|
| `trigger` | `app`, `action`, `id` | Adds content to app (e.g. InstaHub post). App does **not** open automatically. |
| `unlock` | `app`, `id` | Unlocks media in gallery |
| `notify` | `title`, `body`, `app` | Shows notification |
| `toast` | `title`, `body` | Floating toast at top |
| `set_flag` | `key`, `value` | Sets global flag |

### Choice Effects

```
> Text -> label {effects}
```

| Effect | Example |
|--------|---------|
| Increment | `trust += 2` |
| Decrement | `points -= 1` |
| Assignment | `task_done = true` |
| RECORD_PATH | `RECORD_PATH: path_work` |
| UNLOCK_MEDIA | `UNLOCK_MEDIA: assets/images/secret.png` |

### Conditions (operators)

- Comparison: `==`, `!=`, `>`, `<`, `>=`, `<=`
- Logic: `&&`, `||`, `!`

**In `entry_point` and `dependency`:**
- `history.chapter_01 == "path_work"` — path saved in previous chapter
- `global.romance_points > 5` — global variable

### Bridge Between Chapters

**Chapter 1:** record path in choice: `> Yes -> path_yes {RECORD_PATH: path_yes}`

**Chapter 2:** use in `entry_point`:

```yaml
entry_point:
  - if: history.cap1 == "path_yes" -> start_yes
  - else: start
```

### Quick Reference

| Goal | How |
|------|-----|
| Linear dialogue | `ID: Text` and `next: label` |
| Choices | `type: choice` and `> Text -> label {effects}` |
| Branching | `condition: expr` in block |
| Bridge | `RECORD_PATH` in choice + `entry_point` in next chapter |
| Multiple chats | `THREADS` + `trigger: id` + `return_to: id` |
| Pause until chat opened | `trigger: id` **without** `next:` |
| Block chapter | `required_flag` or `dependency` in SETTINGS |
| Image in bubble | `image: path` |
| Unlock gallery | `unlock_gallery: path` or `UNLOCK_MEDIA: path` |
| OS events | `system: trigger/notify/unlock/set_flag` |

---

## For Developers

### Architecture

The engine is **pure Dart** (no Flutter). UI consumes streams and providers.

```
Script .awi → AwiParser → AwiEngine → Streams (onMessage, onChoices, onChapterComplete)
                                        ↓
                              SystemBus.events → Apps (InstaHub, Gallery)
                                        ↓
                              GameNotifier (Riverpod) → UI
```

### .awi vs .awn

| Format | Use | Features |
|--------|-----|----------|
| **.awi** | Primary | SETTINGS, CHARACTERS, [label] blocks, system:, trigger, return_to, OS events |
| **.awn** | Legacy | @labels, linear dialogue, no system: |

### Directory Structure

```
lib/
├── core/           # App registry, system bus, effect registry
├── engine/         # Parser (awi_parser, script_parser), runtime (awi_engine)
│   ├── parser/     # .awi → DialogueNodes, Characters, Choices
│   ├── evaluator/  # Conditions, effects
│   ├── path/       # Chapter headers, path analysis
│   ├── progress/   # RECORD_PATH, history, flags
│   └── save/       # SaveManager, chat persistence
├── apps/           # Chat, InstaHub, Gallery, Settings
├── models/         # Character, DialogueNode, Choice, ChatEntry
├── state/          # Riverpod providers
├── ui/             # Phone shell, dock, message bubbles, themes
└── data/           # Stories loader, gallery catalog, manifest fallback
```

### Main Components

| Component | Role |
|-----------|------|
| **AwiParser** | Parses `.awi` blocks into `DialogueNode` graph and `Character` map. |
| **AwiEngine** | Runs the graph: step-by-step execution, choices, system commands. |
| **SystemBus** | Event bus for `trigger`, `notify`, `toast`, `unlock` commands. |
| **SaveManager** | Persists chat progress, history, and choices via SharedPreferences. |
| **InstaHubNotifier / UnlockedGalleryNotifier** | Listen to SystemBus and update app state. |

### Node Types

- `text`: dialogue message
- `choice`: choices
- `system`: internal nodes (condition, finish_chapter)—not rendered as bubbles

### Engine API

```dart
engine.loadScript(script, chapterId: 'chapter_01');
engine.start(label: 'start', bridgeRules: {...}, dependencyChapterId: 'chapter_01');
engine.next();
engine.choose(choice);
engine.onMessage.listen((node) => ...);
engine.onChoices.listen((choices) => ...);
engine.onChapterComplete.listen((e) => ...);  // e.nextChapterId
```

### Extensibility

| Extension | How to add |
|-----------|------------|
| `system: new_command` | Register in `SystemCommandRegistry` |
| Effect `NEW_PREFIX:` | Register in `EffectRegistry` |
| App/event | Listen to `SystemBus.events` |

---

## App Features

### Messages (Chat)

- Dialogue bubbles by character, configurable colors
- Choices as buttons at bottom
- Images in bubble, tap for fullscreen
- History and choices saved on exit
- Chapter transition with "Continue to Chapter X" button
- Bridge: previous chapter defines start of next
- Auto-roll (configurable)

### Photos (Gallery)

- Unlock via chat or `unlock_gallery`
- Grid and fullscreen viewer

### InstaHub

- Posts unlocked via `system: trigger(app="instahub", action="post", id="p_xxx")`
- Like, comment, view fullscreen

### Settings

- Auto-save, sounds, text speed
- Language, gallery unlock all
- Reset chat history, clear data
- Debug: select chapter

---

## Auto-Discovery

1. Run `dart run tool/generate_stories_manifest.dart` when adding or renaming scripts.
2. The tool scans `assets/scripts/`, writes `assets/scripts/_manifest.json`.
3. The app loads this manifest at startup and parses each script's SETTINGS.
4. No manual manifest updates—add `.awi` files and re-run the generator.

---

## Asset Encryption (Release Builds)

To protect scripts, images, sounds, and videos from casual viewing or editing:

1. **Before building:** Encrypt assets (overwrites `assets/` with encrypted files; backs up to `build/assets_backup/` first):
   ```bash
   dart run tool/encrypt_assets.dart
   ```

2. **Build for release:**
   ```bash
   flutter build windows
   ```

3. **After building:** Restore plain assets for development:
   ```bash
   dart run tool/restore_assets.dart
   ```

**Note:** The decryption key lives in the app; determined users can extract it. This approach mainly protects against casual users and simple file browsing.

---

## Save File Locations

After the exe is built, save data is stored using **SharedPreferences**:

| Platform | Path |
|----------|------|
| **Windows** | `C:\Users\<username>\AppData\Roaming\com.example\awios\shared_preferences.json` |
| **Linux** | `~/.config/com.example/awios/shared_preferences.json` |
| **macOS** | `~/Library/Application Support/com.example.awios/Shared Preferences/` |

The exact path depends on `CompanyName` and `ProductName` in your platform's project config (e.g. `windows/runner/Runner.rc` for Windows). Default is `com.example` / `awios`.

Save data includes: chat progress, choices, gallery unlocks, InstaHub posts, settings, and global flags.

---

## Building for Distribution

### Windows

```bash
# For release with encrypted assets:
dart run tool/encrypt_assets.dart
flutter build windows
dart run tool/restore_assets.dart
```

Output is in `build/windows/x64/runner/Release/`:
- `awios.exe` — main executable
- `data/` — Flutter assets (scripts, images, sounds, videos)
- `flutter_windows.dll` and other DLLs

**To distribute:** Zip the entire `Release` folder. Users must extract and run `awios.exe` from the same folder (or run from the extracted folder). All assets are bundled inside `data/`.

### Linux

```bash
flutter config --enable-linux-desktop   # one-time
flutter build linux
```

Output is in `build/linux/x64/release/bundle/`. Same structure: executable + `data/` + libs. Zip the bundle folder for distribution.

**Note:** Linux builds require the Linux toolchain. On Windows, use WSL (Windows Subsystem for Linux) or a Linux VM.

### macOS

```bash
flutter build macos
```

Output is in `build/macos/Build/Products/Release/` as an `.app` bundle.

---

## Assets

- **Images:** `assets/images/` (tulip.png, mountain_snow.png, sunset_sky.png)
- **Scripts:** `assets/scripts/` (main.awi, template.awi)
- **Sounds:** `assets/sounds/` (message sent/received, toast)
- **Videos:** `assets/videos/` (awiOS.gif for boot screen)
