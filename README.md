# TimeBlocks

A stopwatch for iPhone and iPad where each lap is an intentional block of
time. Blocks can be tagged, noted, nested, and given a timer or alarm.
See [DESIGN.md](DESIGN.md) for how it behaves.

## Requirements
- Xcode 26 with the iOS 26 platform installed (Xcode › Settings › Components)
- iOS 26.1 or later on the device or simulator

## Run it
1. Open `TimeBlocks.xcodeproj`.
2. Pick an iPhone simulator, or a connected iPhone, and press Run (⌘R).
3. For a real device: select the project, then for **both** targets
   (`TimeBlocks` and `TimeBlocksWidget`) choose your team under
   Signing & Capabilities. If the bundle ID is taken, change the prefix
   `io.github.andrew-edelmann` in both targets.

From the command line:
```sh
xcodebuild -project TimeBlocks.xcodeproj -scheme TimeBlocks \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## How it uses the system clock
- **Clocks drawn by the system.** Every running clock is
  `Text(date, style: .timer)`, which iOS draws and updates itself. The app
  does not wake to redraw while a block runs. The Track screen only re-runs
  when a timer or alarm becomes due.
- **AlarmKit.** Block timers and alarms are system alarms, like the Clock
  app's. They ring in silent mode and show on the Lock Screen, where they
  can be snoozed (5 min) or stopped. The app copies those actions back into
  the block's record.
- **Live Activity.** While a session runs, the Lock Screen and Dynamic
  Island show the current block and its clock, with **Next block** and
  **Stop** buttons that work without opening the app.

## Layout
| Folder | Target | Contents |
|---|---|---|
| `TimeBlocks/` | app | App entry, screens (Track, History), assets |
| `Shared/` | app + widget | Data model, AlarmKit alerts, Live Activity data, Lock Screen button intents |
| `TimeBlocksWidget/` | widget extension | Live Activity views (block clock, AlarmKit countdown) |
| `Config/` | — | Info.plist entries for each target |

The project uses Xcode's synchronized folders: new files in these folders
are picked up automatically.
