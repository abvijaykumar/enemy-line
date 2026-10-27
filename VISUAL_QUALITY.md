# Enemy Line visual and experience acceptance criteria

The approved three-screen concept (briefing, run and fight, camp capture) is the artistic target. The current procedural scene is a gameplay blockout and does not satisfy the graphics criteria below. Do not represent generated artwork as an actual runtime screenshot.

## Visual direction

Portrait-first over-the-shoulder camera, believable human proportions, olive tactical equipment, amber actions, translucent charcoal panels, readable white text. Jungle valley at dawn, warm directional light, atmospheric distance, dirt route, camp barricades and watchtower. Preserve threat readability under motion and on a small display.

## Assets required before visual sign-off

- Licensed officer and enemy characters with physically based materials, rigging, locomotion, aiming, firing, hit reactions, cover, and reload animations.
- Helicopter wreck, camp structures, sandbags, terrain, rocks, and foliage with documented rights and mobile level-of-detail variants.
- Lighting/environment maps, bounded shadow distances, texture budgets, and scalable effects tuned using physical-device profiling.
- Weapon feedback: muzzle flash, impact effects, audio, recoil, and optional haptics, synchronized with simulation events.

No production asset budget, minimum device, or asset supplier has been established. These must be resolved before promising the artwork's fidelity at a given frame rate.

## Experience acceptance

- Mission briefing clearly names Crash Valley and explains survive, capture, and extract.
- Controls have at least 44-point hit areas, respect safe areas, and remain usable on the smallest supported iPhone.
- Fire is reachable by the right thumb; movement by the left. Reload, health, objective, ammunition, and squad status remain legible.
- Camp mode clearly indicates cover versus engagement and defenders remaining.
- Input releases on cancellation, pause, backgrounding, and mission completion. Assistive-technology firing can be stopped explicitly.
- No HUD overlap at supported window sizes, orientation changes, or accessibility text sizes. Verify using runtime screenshots; source review alone is insufficient.

## Release gate

Capture actual briefing, running, and camp screenshots on iPhone and compare with the concept at identical portrait dimensions. Review character quality, environment density, lighting, framing, text, and thumb reach. Obtain sustained frame-time, memory, and thermal measurements during repeated full missions on the agreed minimum device. Target 60 fps with a measured 30 fps fallback. Verify iPad and native Mac separately.

Until those checks pass, call this a prototype rather than a visually complete game.
