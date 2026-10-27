# Enemy Line

An offline, native Apple third-person combat runner. A lone officer survives a helicopter crash, captures enemy camps, rescues allies, and fights toward extraction. iPhone-first, with adaptive iPad and native Mac layouts.

## Run on a Mac

Requires Xcode 16+, iOS/iPadOS 18+ or macOS 15+, and XcodeGen 2.42+.

```sh
brew install xcodegen
xcodegen generate
open LastLine.xcodeproj
```

Choose the **LastLine** scheme and an iPhone/iPad simulator or My Mac. For physical devices, configure your signing team and a unique bundle ID in Xcode. No credentials are included.

## Implemented

- Campaign operation selection and sequential unlocking: Crash Valley, Convoy Road, Last Flight.
- Infantry, gunner, vehicle, and helicopter threats; three difficulty settings.
- Three-lane auto-run, jump, slide, drag-to-aim fire, aim assistance, optional automatic fire, reload, and limited grenades.
- Cover battles, enemy camp capture, ally rescue, squad support, health and ammunition resupply, extraction, defeat, replay, and results.
- Local autosave, resume, milestone checkpoint recovery, best completion records, settings, and campaign reset confirmation.
- Procedural soldier/vehicle/helicopter models, moving jungle scenery, camp buildings, sandbags, watchtower, crash wreck, squad followers, rotor and leg animation, tracers, muzzle flashes, explosions, and damage feedback.
- Bundled original synthesized sound effects, optional iPhone haptics, and reduced motion/battery saver options.
- Touch/pointer controls, hardware keyboard controls, extended gamepad support, accessibility labels and accessible firing toggle.
- Application background pause, cancellation-aware input, local privacy manifest, and no backend or network requirement.

## Controls

| Action | Touch | Keyboard | Controller |
|---|---|---|---|
| Change lane | Swipe / arrow buttons | A/D or arrows | D-pad |
| Jump / slide | Swipe up/down / buttons | W/S or arrows | A/B |
| Shoot | Hold FIRE | Hold Space | Right trigger |
| Aim | Drag horizontally on FIRE | Move lane | Move lane |
| Reload | Tap ammunition | R | X |
| Grenade | Tap burst icon | G | Left shoulder |
| Pause | Pause button | Escape | Menu |

At camp, release FIRE for cover; automatic fire can be disabled in settings. Destroy all defenders to recruit an ally and continue. Progress is stored locally using UserDefaults. Continue resumes the latest autosave; Retry checkpoint restores a milestone. A new mission replaces the current resumable mission.

## Validation

```sh
swift test
xcodegen generate
xcodebuild -project LastLine.xcodeproj -scheme LastLine -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project LastLine.xcodeproj -scheme LastLine -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions runs these checks when the code is uploaded. Core tests cover campaign completion at every difficulty, unlocking, deterministic save restoration, cover, grenades, jumping/sliding, reloads, frame rates, and paused/invalid time handling.

**Validation performed:** Swift 6.0.3 on Linux compiled the core engine and passed all 12 XCTest tests, including every operation at every difficulty. Swift parsed all app files successfully. Local packaging checks passed for configuration, resources, privacy, audio, and icons.

**Not validated:** SwiftUI/RealityKit type checking, Apple builds, physical-device gameplay, accessibility, graphics performance, and thermals. This environment has no Xcode. Parsing does not establish platform API correctness. See [release checks](RELEASE_CHECKLIST.md).

## Art and release status

The game is a self-contained **procedural-art implementation**, not a photorealistic production release. No purchased/downloaded character or environment assets are included. The [concept screens](Design/enemy-line-concept.png) and [visual quality criteria](VISUAL_QUALITY.md) remain targets. Reaching those renders requires licensed production assets, skeletal animation, lighting/material work, and real-device performance testing. The generated icon and static briefing backdrop are artwork, not evidence of gameplay rendering quality.

Signing, App Store metadata, App Store review, controller/device QA, and sustained performance measurements remain release tasks. There are three compact handcrafted missions, not an infinite campaign, multiplayer, or a squad-command system. Each mission takes roughly a minute in this first implementation; longer routes can be added after playtesting.

On a Mac, run `bash scripts/validate_apple.sh` to execute the core tests and unsigned builds for both Apple destinations. Optional packaging checks need Python with Pillow and PyYAML (`python3 scripts/check_packaging.py`).
