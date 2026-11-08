# HeadsUp

HeadsUp is a macOS menu-bar app for people who can't use their hands. It lets them control the Mac with **head movement only**, using AirPods with dynamic head tracking as the sensor. Point by turning your head, nod to click, look past the top or bottom edge to scroll, and speak into search fields. Every action is confirmed with a short sound in the AirPods.

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
| **Camera** | Optional | Blink gestures: double blink clicks, triple blink presses Escape | macOS asks when you turn on **Settings → Blink gestures**. Later: *Privacy & Security* → **Camera** → **HeadsUp** |

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
| **Double blink** (optional, Mac camera) | Click |
| **Triple blink** (optional, Mac camera) | Escape |
| Caregiver keyboard: **⌃⌥⌘H** | Pause / resume |

Full details: see the [Gesture cheat-sheet](#gesture-cheat-sheet) section below.

### 7. Build from source

For developers. Requires **Xcode 15.3 or later** (Swift 5.10, needed by `HeadsUpKit/Package.swift`) and [Homebrew](https://brew.sh).

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

### 8. Troubleshooting

| Problem | What to try |
|---|---|
| **The pointer doesn't move** | 1. Check that **Motion & Fitness** is allowed (step 4). 2. Check that the AirPods are connected *and* selected as the sound output. Take them out and put them back in if needed. 3. **Recenter**: tilt right and hold, or look at the middle of the screen and hold still. 4. Make sure HeadsUp isn't paused: tilt left and hold, or press ⌃⌥⌘H. |
| **The pointer moves but clicks don't work** | The **Accessibility** permission is missing or stale. Remove HeadsUp from the Accessibility list and add it back (step 4), then reopen HeadsUp. |
| **The pointer slowly drifts** | This is normal over time (head tracking isn't eye tracking). **Tilt right and hold** to recenter. If it keeps happening, run calibration again from the menu-bar icon. |
| **Voice input doesn't start** | Allow **Microphone** and **Speech Recognition** (step 4). Voice only starts after you nod-click into a text or search field, and never in password fields. Some apps don't expose their fields to macOS, so voice can't start there. |
| **The pointer is too fast or too slow** | Menu-bar icon → *Settings* → **Sensitivity** (see [Tuning](#tuning)). |
| **No confirmation sounds** | Check that the AirPods are the sound output, then menu-bar icon → *Settings* → *Sound*: turn **Mute cues** off and raise **Cue volume**. |
| **Permissions stop working after every rebuild** (developers) | Source builds are ad-hoc signed, so macOS treats each build as a new app. Clear the stale grant with `tccutil reset Accessibility com.hackthechange.HeadsUp`, allow it again, or set `DEVELOPMENT_TEAM` in `project.yml` for a stable signature. |

### 9. Website

The landing page lives in [`frontend/`](frontend/) and is a Next.js static export.

```sh
cd frontend && npm i && npm run dev     # http://localhost:3000
npm run build                           # static site in frontend/out
```

Set the repository URL once, as `GITHUB_URL` in [`frontend/site.config.ts`](frontend/site.config.ts). Every download button and GitHub link uses it. To show the demo video, add `frontend/public/demo.mp4` (and optionally `frontend/public/demo-poster.jpg`).

**Deploy to Vercel:** import the repo, set **Root Directory** to `frontend`, and keep the defaults (framework: Next.js). Nothing else needs configuring.

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
| **Double blink** | Left click at the pointer, like a nod. Needs **Settings → Blink gestures** turned on (off by default). |
| **Triple blink** | Press `Escape`, like a shake. A triple blink never clicks first. |
| **⌃⌥⌘H** (caregiver keyboard) | Pause / resume |

**Blink gestures (optional).** An alternative to nod and shake that uses the Mac's camera. Turn it on in **Settings → Blink gestures** and allow camera access. Blink twice (or three times) in quick succession: a double blink clicks after waiting about half a second for a possible third blink. Ordinary single blinks, eyes resting closed, and a second face in view never act. The camera runs only while blink gestures are on and HeadsUp is tracking; pausing turns it off. Video is analyzed on the Mac only to measure how open the eyes are: nothing is saved or sent, and faces are never identified. Blink actions work while tracking; in voice input and scroll mode use nod and shake.

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

> **Rebuilding resets Accessibility.** The project is ad-hoc signed, so each rebuild can invalidate the grant. If clicks stop working, remove HeadsUp from the Accessibility list and add it again, or set `DEVELOPMENT_TEAM` in `project.yml`.

The App Sandbox is **off**: posting input events and reading other apps' accessibility trees is impossible inside it.

## Calibration & practice (hands-free)

Calibration shows one large dot at a time (center, then the four corners 5% in from the edges, then the center again). Point your head at each dot and hold still for 1.5 s while the ring fills. Each capture is the median raw head pose over the last 0.75 s, and only counts if the head was still (under 5°/s); otherwise the ring restarts. Each side's range is fitted separately. If any side moved less than 5°, or the final center check is more than 3° from the first, calibration starts again. Calibration uses the raw sensor pose only, not smoothing, sensitivity or the pointer spring.

If **Practice after calibration** is turned on (off by default), a **20-second practice** follows with three large circles: point at each one and nod. HeadsUp watches how you reach them and suggests a sensitivity:
- If you overshoot a lot, it suggests calmer.
- If you're slow to reach them, it suggests faster.

**Nod** to accept the suggestion or **shake** to keep the current value.

On later launches, hold still facing the screen for 2 s (or tilt right) to recenter.

## Pointer styles

**Settings → Pointer** offers five styles:
- **Green circle** (default): the v1 halo
- **Hand**: changes shape with what you're doing:
  - open hand when idle
  - pointing finger over buttons and links
  - tap while clicking
  - hand with arrows while scrolling
  - mic badge while listening
  - dimmed with a pause badge while paused
- **Ring**
- **Dot**
- **Crosshair**

You can also change the color, size (S–XL) and opacity, and turn the high-contrast outline on or off. The tilt-hold progress ring and the mode badges work with every style.

**System arrow.** `CGDisplayHideCursor` only reliably hides the arrow while the calling app is frontmost, and HeadsUp almost never is. So by default the arrow stays visible, and the hand's fingertip (each shape's hotspot) is placed exactly on the arrow tip. *Hide system pointer (experimental)* tries to hide it anyway. Whether that works from the background must be checked on real hardware.

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
| Blinks aren't counted | Watch the live indicator in **Blink gestures**. Raise **Eye-closed threshold** (helps with glasses), lower **Shortest blink**, and face the camera in even light |
| Ordinary blinks start a click | Raise **Shortest blink** and lower **Time between blinks** |
| Triple blinks click instead of cancel | Raise **Time between blinks** so the third blink still counts |

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
- `HeadsUpKit/` holds all the logic: `Core`, `MotionInput`, `Processing`, `Gestures`, `Output`, `Permissions`, `PointerAppearance`, `VoiceInput`, `Coordination`. `App/` is the SwiftUI and AppKit shell.
- **Rendering is decoupled from the sensor rate.** Samples arrive at 25–50 Hz and only update the target. A display-synced `CADisplayLink` (`NSScreen.displayLink`, macOS 14) moves the real pointer with a critically damped spring (about 40 ms settle, no overshoot). It posts at most one move per frame, and doesn't move at all when the target is under 3 pt from the cursor (dead zone). Resume/recenter glide in 150 ms.
- **Nods never drag the pointer.** Gestures are recognized from the raw sensor pose. Fast up/down head movement holds the pointer even before the nod threshold is reached, and the moment a nod starts the cursor freezes (target, spring and edge scrolling). A confirmed nod clicks exactly at the frozen spot, holds still for 400 ms, then glides (120 ms) to the head-pointed position, with the smoothing filter re-seeded so the nod's own dip never shows. A rejected nod releases the same way, without a jump. If display frames stop arriving, the sensor loop renders instead.
- **Profiling.** `os_signpost` intervals named `pose` and `frame`, plus a `sample-to-cursor` event, appear under *Points of Interest* in Instruments. The live readout shows the latency.
- States:
  - `needsPermissions → waitingForHeadphones → calibrating → practicing → tracking`
  - from `tracking`: `⇄ paused`, `⇄ scrollMode`, and `→ listening → voiceReview`
  - `awaitingRecenter` after a launch with a saved calibration, or after a reconnect

  Moves are posted only in `tracking` and `practicing`. Clicks, keys, scrolling and text only in `tracking`, `scrollMode`, `listening` and `voiceReview`.

## Checking background delivery

While active, HeadsUp keeps a `ProcessInfo` activity (so App Nap can't throttle it) and a silent `AVAudioEngine` stream (so the AirPods stay the audio route). Check **Settings → Advanced → Live readout → Background check** after switching apps, or run:

```sh
log stream --info --predicate 'subsystem == "com.hackthechange.HeadsUp"'
```

## Known limitations

- **Accessibility coverage varies by app.** Voice-field detection depends on what each app exposes. Native AppKit apps, Safari and Chrome (after `AXManualAccessibility`) are good. Some custom-drawn or game UIs expose nothing. Setting a web field's value through AX doesn't always fire the page's input events. HeadsUp checks that the value stuck and otherwise types the text with key events.
- **Speech focus detection** runs 150 ms after a HeadsUp click, plus on focus-change notifications within 1 s after a click. Fields that focus later are missed.
- **AirPods microphone.** Using it switches Bluetooth to the low-quality call profile while listening, which also degrades audio cues and can disturb head tracking. So HeadsUp uses the **Mac's built-in microphone** by default (*Use Mac's built-in microphone*). Turn that off to use the current system input instead.
- **System pointer hiding:** see Pointer styles above.
- **With double nod turned on, single-nod clicks wait for a possible second nod**, about 0.4 s after the nod is recognized. It's off by default, so clicks are immediate.
- **Scroll routing.** Scroll events go to the window under the last in-content pointer position. Apps that ignore pixel-precise synthetic scroll events may scroll in coarse steps.
- **Absolute pointing drift.** Head orientation isn't gaze, and yaw drifts slowly. Recenter with tilt-right or by holding still.
- **Blink detection depends on the camera view.** Dim light, strong backlight, glare on glasses or turning the head far from the camera (about 40°) can hide the eyes; HeadsUp then ignores blinks rather than guessing. A double blink clicks only after the third-blink wait (*Time between blinks*, 0.5 s by default).
- Not included: dwell-click, drag, right-click, an on-screen keyboard, voice commands beyond dictation, profiles, signing and notarization.

## Tests

`swift test` in `HeadsUpKit/` covers:
- **Movement:** the filter; pointer mapping (pure function of pose, return-to-same-pose, sensitivity, overshoot, yaw wrap); the spring and glide; scroll curves and scroll mode
- **Gestures:** single vs. double nod timing; shake and tilt recognizers
- **Pointer:** pointer context → shape mapping; settings persistence; 3 pt dead zone
- **Calibration & voice:** calibration (median capture, moving capture rejected, center drift check); practice suggestions; text-field classification
- **Nod clicks:** a nod clicks at the onset point with zero cursor movement from onset until 400 ms after the click, then glides to the head position; rejected nods release without a jump
- **Coordinator:** the full state machine with mocks: permissions, calibration, practice, pause/resume, disconnect, edge and mode scrolling, voice flow (listen → Return / undo / keep), and "no events while paused or dictating"
- **Blink gestures:** double blink selects only after the third-blink window, triple blink cancels without selecting, ordinary blinking never acts, cooldown, face loss and frame gaps reset a sequence; the open-eye baseline and hysteresis; the camera runs only while enabled and tracking, and stale or denied camera events never act

Fixtures are regenerated with `python scripts/generate_fixtures.py`.
