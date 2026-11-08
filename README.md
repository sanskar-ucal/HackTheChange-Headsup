# HeadsUp

HeadsUp is a macOS menu-bar app for people who can't use their hands. It lets them control the Mac pointer with **head movement only**, using AirPods with dynamic head tracking as the sensor. Point by turning your head, nod to click, and shake to cancel. Each action is confirmed with a short sound in the AirPods.

| Gesture | Action |
|---|---|
| Point your head at part of the screen | Pointer goes there (absolute mapping) |
| **Nod** (down-up) | Left click where the pointer was when the nod started |
| **Shake** (left-right-left) | Press `Escape` |
| **Tilt left and hold** 1.5 s | Pause / resume |
| **Tilt right and hold** 1.5 s | Recenter: your current pose becomes "center" |
| **⌃⌥⌘H** (caregiver keyboard) | Pause / resume |

The cursor halo (a ring that follows the pointer) is green while tracking, grey while paused and orange while waiting to recenter. It fills during a tilt-hold.

## Requirements

- macOS 14 Sonoma or later. HeadsUp uses `CMHeadphoneMotionManager` directly on the Mac, with no iPhone involved.
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

The app is a menu-bar app (`LSUIElement`) with no Dock icon. Look for the AirPods icon in the menu bar.

### Running without AirPods

```sh
xcodebuild -scheme HeadsUp -derivedDataPath build build
HEADSUP_REPLAY=$PWD/HeadsUpKit/Tests/HeadsUpKitTests/Fixtures/slow_pan.csv \
  build/Build/Products/Debug/HeadsUp.app/Contents/MacOS/HeadsUp
```

In Xcode, you can set the same variable under *Scheme → Run → Arguments → Environment Variables*.

This loops a recorded or synthetic trace through the real pipeline. To make your own trace, use **Settings → Debug → Record motion to CSV**. Recordings go to `~/Library/Application Support/HeadsUp/Recordings/`.

## First-time setup (caregiver, about 2 minutes)

The setup window opens automatically on first launch. You can reopen it from the menu-bar panel under **Setup & permissions…**.

1. **Accessibility.** Click **Request Access**, or go to *System Settings → Privacy & Security → Accessibility* and turn on **HeadsUp**. This lets HeadsUp move the pointer and click. The window rechecks every second.
2. **Motion.** macOS asks the first time the AirPods send motion. Click **Allow**.
3. **AirPods.** Put them on, connect them to the Mac, and select them as the sound output.

> **Rebuilding resets Accessibility.** The project is ad-hoc signed ("Sign to Run Locally"). Each rebuild can change the signature, and macOS then silently ignores the old grant. If clicks stop working after a rebuild, remove HeadsUp from the Accessibility list and add it again. Setting `DEVELOPMENT_TEAM` in `project.yml` gives the app a stable signature.

The App Sandbox is **off** because posting input events to other apps is impossible inside it. HeadsUp is therefore distributed outside the Mac App Store.

## Calibration (hands-free)

Once permissions are granted and the AirPods are connected, calibration starts by itself. A full-screen overlay shows one dot at a time, and a voice says where to look: center, then the four corners. Point your head at each dot and **hold still for 1.5 s** while the ring fills. A tick sounds as each target is captured.

- Each side (left, right, up, down) is measured separately, so an uneven range of motion is fine.
- If any side moved less than 5°, calibration starts again and the voice explains why.
- The calibration is saved. On later launches, and after the AirPods reconnect, HeadsUp asks you to recenter: **hold still facing the screen center for 2 s**, or tilt right and hold. This is needed because the AirPods' yaw reference resets on reconnect and drifts over time.
- To calibrate again, use the menu-bar panel (**Recalibrate**) or **Settings → Calibration**.

## How it works

```
MotionSource → PoseFilter (One Euro) → PointerMapper → CursorController
                   ↘ NodShake / TiltHold recognizers → ActionDispatcher → CursorController + FeedbackService
                              AppCoordinator (state machine) orchestrates all
```

- `HeadsUpKit/` is a Swift package containing all the logic. Its folders are `Core`, `MotionInput`, `Processing`, `Gestures`, `Output`, `Permissions` and `Coordination`.
- `App/` is a thin SwiftUI and AppKit shell. It holds the composition root (`AppEnvironment`), the menu bar, onboarding, the calibration overlay, the cursor halo, settings, and the global hotkey.
- **Onset rollback.** A nod moves the head down, which would drag the pointer down. When a fast pitch or yaw movement starts, the pointer freezes. If a nod or shake is confirmed, the action happens at the pointer position from about 100 ms before the movement began (taken from a 600 ms history buffer). If no gesture is confirmed, the pointer glides back to the head position instead of jumping.
- States: `needsPermissions → waitingForHeadphones → calibrating → tracking ⇄ paused`, plus `awaitingRecenter`. Synthetic events are posted **only** in `tracking`, and there is one gate for that: `AppCoordinator.post(_:)`.
- **Feedback.** AirPods have no haptic motor and no public haptics API. Trackpad haptics only work while a finger is on the trackpad. So the "haptic" feedback is a set of short (<150 ms) synthesized earcons played through the AirPods, behind the `FeedbackService` protocol. The cues are:
  - select: rising two-note
  - cancel: falling two-note
  - pause / resume: low falling / low rising
  - recenter: triple tick
  - calibration step: tick
  - calibration done: arpeggio
  - error: low double

## Tuning

Open **Settings…** from the menu-bar panel. Every number is saved immediately.

| Symptom | Try |
|---|---|
| Pointer shaky when still | Raise **Dead zone** (0.3 → 0.6°) or lower **Min cutoff** |
| Pointer laggy | Raise **Beta** (0.01 → 0.03) or **Min cutoff** |
| Have to turn too far | Raise **Sensitivity**, or recalibrate with smaller movements |
| Nods not detected | Lower **Onset speed** (60 → 45°/s) and **Nod minimum size** (8 → 5°) |
| Clicks while just looking around | Raise **Onset speed** and **Cooldown** |
| Shakes detected as nods (or vice versa) | Lower **Cross-axis limit** |
| Pointer moves the wrong way | Use the **Axis directions** toggles |

The **Live readout** shows yaw, pitch and roll angles and rates in real time, so you can see how fast a user's natural nod actually is.

## Checking background delivery

HeadsUp has to keep receiving motion while another app is in front. To keep that working it does two things while active:

- It holds a `ProcessInfo` activity, which stops App Nap from throttling it.
- It plays a silent `AVAudioEngine` stream, which keeps the AirPods as the active audio route.

To verify:

1. Open **Settings → Live readout**, then switch to another app for about 10 s and come back. The *Background check* line shows the sample rate measured while HeadsUp was in the background. About 25 samples/s or more is good. 0 means delivery stopped.
2. Or watch the log live:
   ```sh
   log stream --info --predicate 'subsystem == "com.hackthechange.HeadsUp"'
   # motion samples/s=25.0 frontmost=false
   ```

If delivery turns out to stop in the background on some macOS version, the fallback is an iPhone relay. It would be one more `MotionSource` implementation; nothing else changes.

## Known limitations

- **Head orientation, not eye gaze.** Accuracy depends on calibration and on the user's head control.
- **Yaw drifts** slowly, and resets when the AirPods reconnect. Recenter with tilt-right or by holding still.
- Recentering via tilt-right captures the neutral pose while the head is tilted. Yaw and pitch change little when you tilt, but a still-pose recenter is slightly more precise.
- When the head starts moving fast without a gesture, the pointer freezes for up to 0.7–0.9 s before gliding on. A fast deliberate pan can feel sticky.
- Multiple displays use the union of all screens (Settings → *Span all displays*). The default is the main display only.
- Not in this MVP: dwell-click, scrolling, drag, right-click, on-screen keyboard, voice commands, multiple profiles, signing and notarization.
- The motion permission deep link opens *Privacy & Security* in general. macOS has no dedicated pane link for headphone motion.

## Tests

`swift test` in `HeadsUpKit/` covers:

- One Euro filter
- pointer mapping (asymmetric ranges, dead zone, ±π yaw wrap)
- calibration fit, validation and the dwell session
- screen geometry and coordinate conversion
- the nod/shake and tilt-hold recognizers
- cursor history
- the CSV codec and replay source
- the coordinator state machine with mocks: transitions, disconnect, no events while paused, rollback click position

Synthetic fixtures live in `HeadsUpKit/Tests/HeadsUpKitTests/Fixtures/`. They are regenerated with `python scripts/generate_fixtures.py`, which mirrors `TraceSynth.swift`.
