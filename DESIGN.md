# TimeBlocks design, v0

Goal: a stopwatch where laps are intentional blocks of time. The user starts a new block on purpose. The app records when each block happened, how long it lasted, and what it was.

## Data model (SwiftData)
- **Session**: one Start-to-Stop run. Fields: startedAt, endedAt (nil while running), blocks (all blocks, nested or not).
- **Block**: one lap. Fields: startedAt, endedAt (nil while open), note, tags (many-to-many), parent, children, plus the alert fields below.
- **Tag**: a user-defined key-value pair. The value is optional. Examples: "focus" (key only), "project: thesis" (key and value). Tags are stored once and reused across blocks. The app ships with no tags.

## Nesting
A block can sit inside another block. The parent keeps running while its children run, so it spans them. Example: "Doing groceries" contains "Biking there", "Picking up stuff", "Paying" and "Biking back".

Open blocks always form a chain from the outermost to the innermost. The innermost open block is the "current" block, and the big clock shows it.

Controls while running:
- **Next block**: ends the current block and starts a sibling (same parent) at the same instant.
- **Start inside**: starts a child of the current block. The current block keeps running.
- **End block**: ends the current block. Its parent becomes current. Only shown when the current block has a parent.
- **Stop**: ends every open block and ends the session.

Grouping after the fact: in History, select blocks that are siblings and next to each other, then press Group. This creates a new parent block that spans them. (On iPhone and iPad, press Edit first to select.)

## Timer and alarm
Alerts are optional. A block has none unless the user sets one. Each block can have at most one alert, set from the Track screen: a **timer** (counts down a set length, starting when it is set) or an **alarm** (rings at a clock time, next time the clock shows it).

Stored on the block: kind, when it was set, timer length, when it was first meant to ring, when it rings next, number of snoozes, and total time snoozed.

- The alert is a system alarm (AlarmKit), the same system the Clock app uses. It rings even in silent mode, and a timer's countdown shows on the Lock Screen. From the system alert the user can Snooze (5 min) or Stop; the app copies that into the block's record (snooze count and time, or dismissed).
- When the app is open, a banner also offers Snooze (1, 5, 10 or 15 min) or Dismiss.
- If the user refuses alarm permission, alerts only show inside the app.
- Ending the block cancels an alert that has not rung. The record stays.
- Clear removes the alert and its record.
- History shows the alert details for a block.

## Days
A session covers at most one calendar day, so the top-level clock never runs for more than 24 hours. At midnight the running session ends and a new one starts at 00:00. Open blocks are not cut: they move to the new day's session with everything nested inside them, and keep their real start times. A sleep block started at 11 PM and ended at 8 AM is one 9-hour block in the new day; the session clock shows time since midnight.

iOS may not run the app at midnight, so the switch also happens on the next action (opening the app, any button, a Lock Screen button). The result is the same, because every time is a stored date. Days on which the app was not used get no session. The Lock Screen's session clock keeps counting from the old start until the app next runs.

## Lock Screen
While a session runs, a Live Activity shows the current block's tags, where it sits ("Inside: …"), its clock and the session clock. It has **Next block** and **Stop** buttons, which run in the app without opening it. iOS ends a Live Activity after about 8 hours; the session keeps running, and the activity comes back the next time the Track screen is opened.

## Battery
Every running clock is drawn by the system from a start date (`Text(date, style: .timer)`), on screen, on the Lock Screen and in the Dynamic Island. The app does not redraw while a block runs. The Track screen re-runs only when an alert becomes due.

## Behavior
- Blocks at the same level have no gaps: "Next block" uses one timestamp to end one block and start the next.
- Elapsed time is computed from stored dates, not a running counter. A relaunch or a backgrounded app loses nothing.
- Tagging: type "key" or "key: value" and press Add. The tag is created if it is new, and applied to the block. Every saved tag shows as a chip that toggles on and off with a tap. Chips stay in alphabetical order so they do not move under the finger. Long-press a chip to delete the tag.
- Tags and the note can be edited while the block runs and afterwards in History.

## Not yet built (open questions)
- More than one alert per block. A repeating timer.
- Ungroup, or moving a block into a different parent.
- Pause (it would break the "no gaps" rule).
- Editing start and end times after the fact.
- Renaming tags.
- Analysis of sequence and duration (for example, which block follows which, or time per tag including nested time).
- Export (CSV or JSON), iCloud sync, home-screen widgets.
- Choosing the snooze length on the Lock Screen (it is fixed at 5 min there).
