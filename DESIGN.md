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

- A local notification rings it when the app is in the background. When the app is open, a banner offers Snooze (1, 5, 10 or 15 min) or Dismiss.
- Ending the block cancels an alert that has not rung. The record stays.
- Clear removes the alert and its record.
- History shows the alert details for a block.

## Behavior
- Blocks at the same level have no gaps: "Next block" uses one timestamp to end one block and start the next.
- Elapsed time is computed from stored dates, not a running counter. A relaunch or a backgrounded app loses nothing.
- Tagging: type "key" or "key: value" and press Add. The tag is created if it is new, and applied to the block. Every saved tag shows as a chip that toggles on and off with a tap. Chips stay in alphabetical order so they do not move under the finger. Long-press a chip to delete the tag.
- Tags and the note can be edited while the block runs and afterwards in History.

## Not yet built (open questions)
- Snooze or dismiss from the notification itself (today you must open the app).
- More than one alert per block. A repeating timer.
- Ungroup, or moving a block into a different parent.
- Pause (it would break the "no gaps" rule).
- Editing start and end times after the fact.
- Renaming tags.
- Analysis of sequence and duration (for example, which block follows which, or time per tag including nested time).
- Export (CSV or JSON), iCloud sync, widgets, Live Activity.
