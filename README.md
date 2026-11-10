# HeadsUp

HeadsUp is a hands-free Mac mouse for people with tetraplegia. It's a macOS menu-bar app that turns **head movement** into full pointer control, using AirPods with dynamic head tracking as the sensor. Point by turning your head, nod to click, look past the top or bottom edge to scroll, and speak into search fields. Every action is confirmed with a short sound in the AirPods. A caregiver can help with the one-time setup; after that, everyday use is hands-free.

## Installation

This guide is written so a caregiver or family member can set HeadsUp up in about 10 minutes. After setup, daily use is completely hands-free.

**Steps:** [Requirements](#1-requirements) · [Download](#2-download) · [First open](#3-first-open-the-unidentified-developer-warning) · [Permissions](#4-permissions-step-by-step) · [Calibrate](#5-connect-airpods-and-calibrate) · [Gestures](#6-gesture-cheat-sheet) · [Build from source](#7-build-from-source) · [Troubleshooting](#8-troubleshooting) · [Website](#9-website)

### 1. Requirements

- **A Mac with macOS 14 Sonoma or later.** To check: Apple menu → *About This Mac*.
- **AirPods that support head tracking:** AirPods Pro (any generation), AirPods (3rd generation or later), AirPods Max, or Beats with head tracking.
- **The AirPods connected to this Mac and selected as its sound output.** Click *Control Center* (top right of the screen) → *Sound* and choose the AirPods.
- **Head tracking / spatial audio support turned on.** In the same *Sound* menu, with the AirPods selected, make sure Spatial Audio isn't switched off. If you see **Head Tracked**, choose it. AirPods firmware updates install automatically while the AirPods charge near an iPhone or Mac.

### 2. Download

1. Go to the **[latest release](../../releases/latest)** (on the GitHub page: *Releases* on the right, then the newest one).
2. Under **Assets**, click the **`.zip`** file for HeadsUp to download it.
3. Open your **Downloads** folder and double-click the zip to unzip it. You now have **HeadsUp.app**.
4. Drag **HeadsUp.app** into your **Applications** folder.

### 3. First open (the "unidentified developer" warning)

HeadsUp isn't signed with a paid Apple developer certificate yet. So the first time it opens, macOS shows a warning such as *"HeadsUp can't be opened because it is from an unidentified developer"* or *"Apple could not verify HeadsUp…"*. This is expected. You only need to fix it once:

**Option A: right-click → Open**
1. In *Applications*, **right-click** (or Control-click) **HeadsUp** and choose **Open**.
2. In the dialog, click **Open**.

**Option B: System Settings** (use this on newer macOS versions if Option A doesn't show an Open button)
1. Double-click HeadsUp once and close the warning.
2. Open Apple menu → *System Settings* → **Privacy & Security**.
3. Scroll down to the *Security* section. Next to *"HeadsUp was blocked…"*, click **Open Anyway**, then confirm with your password or Touch ID.

**Option C: Terminal** (if you're comfortable with it). This removes the download quarantine flag:

```sh
xattr -dr com.apple.quarantine /Applications/HeadsUp.app
```

HeadsUp is a **menu-bar app** with no Dock icon. Look for its icon at the top right of the screen. The setup window opens automatically on first launch. You can reopen it any time from the menu-bar icon → **Setup & permissions…**.

### 4. Permissions, step by step

HeadsUp needs two permissions, plus two optional ones for voice search. The setup window has a button for each that opens the right place in System Settings.

| Permission | Needed? | Why | Where to turn it on |
|---|---|---|---|
| **Accessibility** | Required | Controls the cursor: lets HeadsUp move the pointer, click, scroll and type in other apps | *System Settings* → *Privacy & Security* → **Accessibility** → turn on **HeadsUp**. If it isn't listed, click **+** and pick it from Applications. |
| **Motion & Fitness** | Required | Lets HeadsUp read head movement from the AirPods | macOS asks the first time the AirPods send motion: click **Allow**. To change it later: *Privacy & Security* → **Motion & Fitness** → **HeadsUp** |
| **Microphone** | Optional | Voice search: speak into search fields | macOS asks the first time voice input starts. Later: *Privacy & Security* → **Microphone** → **HeadsUp** |
| **Speech Recognition** | Optional | Turns speech into text, on the Mac when supported | macOS asks together with the microphone. Later: *Privacy & Security* → **Speech Recognition** → **HeadsUp** |

> **The toggle is on, but it still doesn't work?** This often happens after updating or replacing the app, because macOS remembers the old copy.
> 1. Quit HeadsUp (menu-bar icon → **Quit**).
> 2. In *Privacy & Security* → **Accessibility**, select **HeadsUp** and click **−** to remove it.
> 3. Click **+**, choose **Applications → HeadsUp**, and turn it on again.
> 4. Open HeadsUp again.
>
> The same steps fix Motion & Fitness, Microphone and Speech Recognition.

### 5. Connect AirPods and calibrate

1. Put the AirPods in, and check that they're the Mac's sound output.
2. Open HeadsUp. It speaks short prompts through the AirPods to guide you. Follow them.
3. **Calibration.** One large dot appears at a time: the center, then each of the four corners, then the center again. **Look at each dot and hold still until the ring around it fills** (about 1.5 seconds). If you move, the ring simply starts again.
4. When it's done, HeadsUp says *"Calibration complete."* The pointer now follows your head.

HeadsUp remembers the calibration. On later launches, look at the middle of the screen and hold still for 2 seconds (or tilt right and hold) to recenter.

### 6. Gesture cheat sheet

| Do this | What happens |
|---|---|
| **Look** around the screen | Moves the pointer |
| **Nod** (small down-up) | Click. The pointer holds still while you nod |
| **Shake** (left-right) | Escape / back. After voice input, undoes the text |
| **Look past the top or bottom edge** | Scroll |
| **Tilt left and hold** (1.5 s) | Pause / resume |
| **Tilt right and hold** (1.5 s) | Recenter |
| Caregiver keyboard: **⌃⌥⌘H** | Pause / resume |

Full details: see the [Gesture cheat-sheet](#gesture-cheat-sheet) section below.

### 7. Build from source

For developers. Requires **Xcode 15 or later** and [Homebrew](https://brew.sh).

```sh
brew install xcodegen
xcodegen generate          # run in the repo root; creates HeadsUp.xcodeproj from project.yml
open HeadsUp.xcodeproj
```

In Xcode, select the **HeadsUp** scheme and click **Run** (⌘R).

To run the logic tests (no AirPods needed):

```sh
cd HeadsUpKit && swift test
```

[Build & run](#build--run) below covers running without AirPods and more.

## Gesture cheat-sheet

| Gesture | Action |
|---|---|
| Point your head | Moves the pointer (absolute: looking at a corner puts it in that corner; the same head pose always gives the same point). |
| **Nod** (down-up) | Left click, like a mouse: the cursor freezes the moment the nod starts, clicks exactly there, stays still for 400 ms (**Hold after click**), then glides back to where your head points. |
| **Double nod** (two nods within 0.9 s) | Scroll mode on/off, if **Double nod for scroll mode** is turned on (off by default, so single nods click instantly). The pointer freezes; look up or down to scroll. |
| **Shake** (left-right-left) | Press `Escape`. In scroll mode it exits; after voice input it undoes the inserted text. |
| **Edge push** | Keep looking past the top or bottom edge (more than 3°) to scroll. Optionally left/right too. |
| **Tilt left and hold** 1.5 s | Pause / resume. Works in every mode, including while listening. |
| **Tilt right and hold** 1.5 s | Recenter: your current pose becomes "center". |
| **⌃⌥⌘H** (caregiver keyboard) | Pause / resume |

**Voice input.** Nod-click into a search field, and HeadsUp starts listening: a mic badge appears on the pointer and your words show in a bubble. Stop talking for 1.5 s, or nod, and the text is inserted. Then:
- **nod** presses Return (runs the search)
- **shake** undoes the text
- **doing nothing for 4 s** keeps the text and goes back to pointing

Password fields never start listening.

## Requirements

- macOS 14 Sonoma or later. HeadsUp uses `CMHeadphoneMotionManager` directly on the Mac.
- AirPods Pro (any generation), AirPods (3rd gen or later), AirPods Max, or Beats with head tracking. They must be connected to this Mac and selected as its sound output.
- Xcode 15.3 or later (Swift 5.10).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build & run

```sh
xcodegen generate                    # creates HeadsUp.xcodeproj from project.yml
open HeadsUp.xcodeproj               # then Run (⌘R), or:
xcodebuild -scheme HeadsUp -configuration Debug build

cd HeadsUpKit && swift test          # all logic is unit-tested without hardware
```

The `.xcodeproj` is generated, so it is git-ignored. Edit `project.yml` instead.

### Running without AirPods

```sh
xcodebuild -scheme HeadsUp -derivedDataPath build build
HEADSUP_REPLAY=$PWD/HeadsUpKit/Tests/HeadsUpKitTests/Fixtures/slow_pan.csv \
  build/Build/Products/Debug/HeadsUp.app/Contents/MacOS/HeadsUp
```

In Xcode, set the same variable under *Scheme → Run → Arguments → Environment Variables*. To record your own trace, use **Settings → Advanced → Record motion to CSV**.

## First-time setup (caregiver, about 3 minutes)

The setup window opens on first launch. You can reopen it from the menu-bar panel under **Setup & permissions…**.

1. **Accessibility** (required). Lets HeadsUp move the pointer, click, scroll, type and read buttons and fields in other apps.
2. **Motion** (required). macOS asks the first time the AirPods send motion. Click **Allow**.
3. **AirPods**. Connect them and select them as the sound output.
4. **Microphone + Speech Recognition** (optional). Only needed for voice input. Recognition runs on the Mac when supported.

The App Sandbox is **off**: posting input events and reading other apps' accessibility trees is impossible inside it.

## Tuning

| Symptom | Try |
|---|---|
| Pointer too jumpy / sensitive | Lower **Sensitivity** (Calmer), raise **Smoothing** |
| Have to turn too far | Raise **Sensitivity** |
| Hard to hit small things | Lower **Sensitivity** |
| Nods aren't clicking | Check the **Gesture log** in Advanced → Live readout: every nod candidate is listed as confirmed or rejected with the reason |
| Nods not detected | Lower **Nod/shake speed** and **Nod size** |
| Scrolling too fast / slow | **Scroll speed**; **Edge push distance** sets how far past the edge to look before scrolling starts |
| Pointer moves the wrong way | **Advanced → Invert** toggles |

Every Settings control has a 44 pt target, and sliders have −/+ buttons, so Settings itself can be used with head pointing and nods.

## How it works

```
MotionSource → PoseFilter (One Euro) → PointerMapper (pure mapping × sensitivity)
   → target ───────────────────┐
   → DoubleNod/NodShake/Tilt   ├→ AppCoordinator (state machine)
                               └→ display link: PointerAnimator (spring/glide) → CursorController
                                                 ScrollController · TextInserter · FeedbackService
```

- Every tunable (gains, thresholds, timings, pointer appearance) lives in one `HeadsUpSettings` model, persisted to `UserDefaults` (key `HeadsUp.settings.v2`).
- `HeadsUpKit/` holds all the logic: `Core`, `MotionInput`, `Processing`, `Gestures`, `Output`, `Permissions`, `PointerAppearance`, `Targeting`, `VoiceInput`, `Coordination`. `App/` is the SwiftUI and AppKit shell.
- **Rendering is decoupled from the sensor rate.** Samples arrive at 25–50 Hz and only update the target. A display-synced `CADisplayLink` (`NSScreen.displayLink`, macOS 14) moves the real pointer with a critically damped spring (about 40 ms settle, no overshoot). It posts at most one move per frame, and doesn't move at all when the target is under 3 pt from the cursor (dead zone). Resume/recenter glide in 150 ms.
- **Nods never drag the pointer.** Gestures are recognized from the raw sensor pose. Fast up/down head movement holds the pointer even before the nod threshold is reached, and the moment a nod starts the cursor freezes (target, spring and edge scrolling). A confirmed nod clicks exactly at the frozen spot, holds still for 400 ms, then glides (120 ms) to the head-pointed position, with the smoothing filter re-seeded so the nod's own dip never shows. A rejected nod releases the same way, without a jump. If display frames stop arriving, the sensor loop renders instead.
- **Profiling.** `os_signpost` intervals named `pose` and `frame`, plus a `sample-to-cursor` event, appear under *Points of Interest* in Instruments. The live readout shows the latency.
- States:
  - `needsPermissions → waitingForHeadphones → calibrating → practicing → tracking`
  - from `tracking`: `⇄ paused`, `⇄ scrollMode`, and `→ listening → voiceReview`
  - `awaitingRecenter` after a launch with a saved calibration, or after a reconnect

  Moves are posted only in `tracking` and `practicing`. Clicks, keys, scrolling and text only in `tracking`, `scrollMode`, `listening` and `voiceReview`.

## Tests

`swift test` in `HeadsUpKit/` covers:
- **Movement:** the filter; pointer mapping (pure function of pose, return-to-same-pose, sensitivity, overshoot, yaw wrap); the spring and glide; scroll curves and scroll mode
- **Gestures:** single vs. double nod timing; shake and tilt recognizers
- **Pointer:** pointer context → shape mapping; settings persistence; 3 pt dead zone
- **Calibration & voice:** calibration (median capture, moving capture rejected, center drift check); practice suggestions; text-field classification
- **Nod clicks:** a nod clicks at the onset point with zero cursor movement from onset until 400 ms after the click, then glides to the head position; rejected nods release without a jump
- **Coordinator:** the full state machine with mocks: permissions, calibration, practice, pause/resume, disconnect, edge and mode scrolling, voice flow (listen → Return / undo / keep), and "no events while paused or dictating"

Fixtures are regenerated with `python scripts/generate_fixtures.py`.
