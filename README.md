# Last Line

Native Apple third-person combat runner. First milestone: a playable blockout of Crash Valley, not production graphics.

## Open on a Mac

Requires Xcode 16+, iOS/iPadOS 18+ or macOS 15+, and XcodeGen (`brew install xcodegen`).

```sh
xcodegen generate
open LastLine.xcodeproj
```

Select the LastLine scheme and an iPhone simulator, iPad simulator, or My Mac. For a physical device, select your own signing team and a unique bundle identifier in Xcode. No signing credentials are stored in this repository.

## Current prototype

- RealityKit 3D scene with a following-camera composition and procedural blockout geometry.
- Three movement lanes, jump, press-and-hold fire, assisted lane targeting, ammunition and reload.
- Infantry encounters, obstacle damage, automatic stop at Ridge Camp, cover while not firing.
- Three camp defenders; clearing them recruits an ally who fires independently.
- Extraction, defeat, results, retry, pause, and automatic pause on backgrounding.
- Shared deterministic Swift mission simulation with XCTest coverage.
- Shared iPhone, iPad, and native macOS app target, touch/pointer buttons.

Swipe left/right or tap arrows to switch lanes. Swipe up or tap Jump to clear obstacles. Hold FIRE to shoot threats in your lane. At the camp, switch lanes to defeat all three defenders; releasing FIRE returns to cover. Tap ammunition to reload.

## Validation status

This workspace is Linux and has neither Swift nor Xcode. The source has **not been compiled or playtested** here. GitHub Actions is configured to run Swift tests and build both Apple destinations after the repository is connected. Physical-device frame timing and thermals remain unmeasured.

## Next milestones

1. Compile and playtest on a Mac; fix platform/API issues and tune the core loop on a physical iPhone.
2. Add checkpoint persistence, drag aiming, controller/keyboard input, and accessibility improvements. Slide and grenades are not implemented yet.
3. Replace blockout geometry with licensed realistic assets, character animation, camp scenery, audio, haptics, and scalable graphics settings.
4. Validate sustained performance, then add more missions, vehicles, and helicopters.

No multiplayer, monetization, backend, or external asset dependencies are included. The original concept assumed iOS 17/macOS 14; this prototype raises the baseline to iOS 18/macOS 15 to use RealityView across the requested platforms.
