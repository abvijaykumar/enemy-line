# Release validation

The 12 core XCTest tests passed on Linux with Swift 6.0.3. App source parsing and packaging checks also passed. The Apple build, runtime, and device checks below remain pending; this document is not evidence of those checks passing.

## Build

- Generate project with XcodeGen 2.42+; use Xcode 16+.
- Run all Swift package tests. Build iOS Simulator, iOS Device (signed), and native macOS destinations.
- Confirm icon, synthesized audio, and PrivacyInfo.xcprivacy are bundled once.
- Verify provisioning team, unique bundle ID, app display name, version/build number, and minimum OS versions.

## Complete playthrough

- New install: inspect mission briefing and manual; locked missions are unavailable.
- Finish all three operations at each difficulty. Verify camp stop, cover safety, resupply, rescue, squad support, vehicles, helicopters, extraction, and campaign completion.
- Test firing without ammunition, interrupted reload, missing grenades, simultaneous movement/fire, drag aiming, and toggling aim assistance/automatic fire.
- Fail before camp, at camp, and after camp. Retry the right milestone with its saved resources; verify replay does not corrupt records.
- Force-quit during running, cover combat, reload, and after capture. Continue from a valid saved state.
- Replay a completed mission slower and faster; preserve the best completion record.
- Confirm reset deletes progression only after confirmation and is unavailable during a mission.

## Input and layouts

- Test a small iPhone, large iPhone, iPad portrait/landscape, iPad multitasking, and resizable Mac windows.
- Test VoiceOver, increased text sizes, safe areas, motion reduction, and switch input. Firing must have an accessible stop action.
- Test touch cancellation, keyboard key-up, controller connection/disconnection, focus loss, settings sheets, backgrounding, and pause. No input should remain latched.
- Verify left/right D-pad, A/B/X, trigger, shoulder, and Menu on at least one physical controller.

## Graphics and performance

- Compare actual screenshots of briefing, running, and camp against the concept. Current procedural geometry does not satisfy the realism target.
- Agree on the minimum supported hardware and measure 15 minutes of repeated play: frame time, memory, energy, and thermals.
- Target 60 fps; verify battery saver caps simulation updates at approximately 30 Hz. Neither target has been measured yet; renderer refresh policy still requires device tuning.
- Profile entity/draw-call count, scenery, shadows, and audio before increasing route length or art density.

## Distribution

- Review generated icon/art rights, bundled audio provenance, and future third-party asset licenses.
- Review required-reason privacy declarations and App Store privacy answers (no tracking, no remote data collection in this implementation).
- Confirm age rating, content disclosures, accessibility, support contact, marketing screenshots, and store description.
- Archive, validate, and distribute through TestFlight before App Store submission.
