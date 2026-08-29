# Packaged release-candidate manual QA

Use this checklist for every release candidate (RC). It is a repeatable test of
the **installed, packaged artifact** that will be shipped to players. A run from
the source tree, an editor, or a loose LÖVE project does not count.

## Release gate and evidence

1. Obtain the candidate through the intended distribution channel (preferably a
   clean Steam branch/depot install) and record its depot/manifest ID and SHA-256.
2. Copy this document or the tables into the release test record. Complete the
   run header and one result row for every matrix ID. Use `Pass`, `Fail`,
   `Blocked`, or `N/A`; `N/A` requires the release owner's written approval.
3. Attach screenshots, logs, save files, performance captures, and crash dumps
   to the test record or linked defect. Never overwrite the only reproduction
   save.
4. Retest fixes using a newly packaged candidate and record a new build number;
   do not edit a failure into a pass.
5. **Do not tag a release until every Release Blocker (`RB`) row passes against
   the exact packaged artifact being tagged.** Open defects, `Blocked`, `N/A`,
   and source-tree results do not satisfy the gate.

### Run header

| Field | Value |
| --- | --- |
| Product/version | |
| Build number (in-game) | |
| Package/depot/manifest ID | |
| Artifact SHA-256 | |
| Distribution branch/channel | |
| Previous released version used for migration | |
| Test date/time and time zone | |
| Minimum-target hardware specification | |
| OS/platform and version | |
| CPU / GPU / driver / RAM | |
| Steam client version (or offline) | |
| Tester | |

### Result record (one line per executed matrix row)

| Matrix ID | Build number | Platform | Display mode + resolution/aspect | Input device | Tester | Result | Defect/evidence link | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | |

Unless a row says otherwise, verify correct visuals and text, responsive input,
correct audio, stable frame pacing, no errors/crashes, and persistence after a
clean quit and relaunch. `RB` means release-blocking; `P1` is required coverage
but may be waived only through the documented release exception process.

## Installation, saves, and lifecycle

| ID | Gate | Setup / action | Expected result |
| --- | --- | --- | --- |
| INS-01 | RB | Remove the game and its user-data directory, reboot, then install the RC through the release channel. Launch it from the client, not the repository. | Install has no stale/local files; first launch reaches the main menu, reports the recorded build, creates valid defaults, and needs no developer runtime. |
| INS-02 | RB | Install over the current public release without deleting its files; launch and play one map. | Client updates cleanly; no obsolete-file errors, duplicate content, or version mismatch. |
| SAVE-01 | RB | In the previous public build create saves at: new profile, partial campaign, final map unlocked, completed campaign, custom settings/keybinds, and partially completed achievements. Back them up, install RC, and load each copy once. | Migration is automatic and non-destructive; campaign medals/unlocks, stats, achievements, loadout, settings, and bindings retain valid values. Play, save, relaunch, and confirm the migrated format remains stable. |
| SAVE-02 | RB | Test separate corrupted copies: truncated/empty file, malformed bytes, valid file with a damaged field/table, and newest save damaged when a backup exists. Launch once per copy. | Game does not crash or hang. It uses a valid backup or safe defaults, clearly communicates recovery where applicable, preserves recoverable progress, and writes a usable save only after recovery. |
| SAVE-03 | P1 | Make the save read-only or temporarily deny write access; play until a save point, restore access, and relaunch. | Failure is handled without a crash or false success; recovery does not silently destroy the last good save. |
| FLOW-01 | RB | From an active campaign run trigger defeat, choose Restart, lose again, and return to menu. | Defeat recap is correct; Restart resets wave, enemies, towers, money, lives, ability charge/effects, pause state, and run stats without changing earned progression. Menu remains usable. |
| FLOW-02 | RB | Win a non-final map, inspect recap/rewards, continue, then replay and choose menu/restart where offered. | Victory is recorded once, correct next content unlocks, rewards are not duplicated, and each navigation path starts a clean run. |
| FLOW-03 | RB | Win the final campaign map, exercise its menu flow, relaunch, then inspect the saved campaign completion. | Final completion, medals, achievements, and campaign progress persist correctly. |
| LIFE-01 | RB | Quit from main menu, active play, pause menu, victory, and defeat. Relaunch after each. Also close via the OS window control once. | Process exits promptly with no hang/crash/orphan process; Steam status clears; the last completed save transaction is intact and no in-progress run is falsely awarded. |

## Campaign and bosses

Execute `CAMP-01` once for **every campaign map at every difficulty**. Record a
separate result row for each combination (for example `CAMP-01/map-3/hard`). Do
not infer one difficulty from another.

| ID | Gate | Coverage / action | Expected result |
| --- | --- | --- | --- |
| CAMP-01 | RB | Complete every campaign map on **Easy**, **Normal**, and **Hard**, including at least one leak and one clean wave per difficulty. Verify previews, starting money/lives, rewards, map progression, and medals. | All maps are completable; selected difficulty is used in play/recap and persists; difficulty-specific economy/enemy/boss behavior and the correct medal/completion state apply without cross-difficulty corruption. |
| BOSS-01 | RB | For every authored boss encounter on each difficulty, reach the boss normally; observe spawn, boss HUD, abilities/attacks/adds/phases, leak behavior, and defeat/kill. Replay at least one encounter after restart. | Correct boss spawns on schedule and path; HUD/health/phases and special behavior are correct; kill/leak resolves exactly once, awards correct charge/stat/progression, and leaves no stuck entities or music/UI. |

## Towers and stat-only upgrades

The mandatory release gate covers the shipped **stat-only game**.
For each tower, place it legally and attempt an illegal placement; inspect it,
upgrade repeatedly through maximum level, and verify
each preview against the resulting damage, fire rate, range, targeting controls,
damage meter, sell/refund behavior, and restart cleanup.

| ID | Gate | Tower | Required stat-only coverage |
| --- | --- | --- | --- |
| TWR-01 | RB | Slow | Base through maximum level; damage, fire-rate, range, slow duration, targeting, and sell values. |
| TWR-02 | RB | Lancer | Base through maximum level; damage, fire-rate, range, targeting, and sell values. |
| TWR-03 | RB | Poison | Base through maximum level; damage, fire-rate, range, poison duration/stacks, targeting, and sell values. |
| TWR-04 | RB | Cannon | Base through maximum level; damage, fire-rate, range/splash, targeting, and sell values. |
| TWR-05 | RB | Shock | Base through maximum level; damage, fire-rate, range/chain behavior, targeting, and sell values. |
| TWR-06 | RB | Plasma | Base through maximum level; damage, fire-rate, range/tick behavior, targeting, and sell values. |

## Active abilities

For each ability, unlock/equip it through normal progression, fill charge normally,
activate by mouse, rebound keyboard key, and controller. Test insufficient charge,
cooldown/active lockout, cancel (for targeted abilities), invalid and valid targets,
edge-of-map targeting, pause/focus loss during targeting/effect, and restart cleanup.

| ID | Gate | Ability | Ability-specific expected result |
| --- | --- | --- | --- |
| ABL-01 | RB | Meteor | Point preview is accurate; impact delay/area damage and visuals occur once; invalid placement is safe. |
| ABL-02 | RB | Frost Nova | Only valid enemy area can confirm; affected enemies slow for the displayed duration and recover. |
| ABL-03 | RB | Overdrive | Only valid tower area can confirm; marked towers gain and then lose the displayed haste without permanent stat drift. |
| ABL-04 | RB | Gravity Well | Valid enemies are pulled/damaged for the displayed area/duration; pathing and cleanup remain valid. |
| ABL-05 | RB | Gold Rush | Instant activation visibly runs for the displayed duration and modifies only eligible income; stacking/restart cannot retain it. |
| ABL-06 | RB | Last Stand | Only valid tower area can confirm; buff/extra volley behavior occurs as described and fully expires. |

## Progression and achievements

| ID | Gate | Setup / action | Expected result |
| --- | --- | --- | --- |
| PROG-01 | RB | From a fresh save, progress through every map reward and final completion. At each step inspect locked maps, towers, abilities, loadout slots before and after earning each prerequisite. | Only intended items unlock, exactly once and at the correct step; locked content cannot be selected; unlock cards/text are accurate; state survives relaunch. |
| ACH-01 | RB | Using fresh/repro saves, trigger every packaged achievement condition: boss totals; enemy totals; 250/1000 kills for each of six towers; Easy/Normal/Hard campaign clears; Normal/Hard no-leak clears; first/100 tower upgrades; last-second condition. Check in-game Progress and Steam. | Each achievement/stat increments only from eligible gameplay, unlocks once at the threshold, matches Steam after callback/store, persists offline locally, and does not unlock early or regress. |
| ACH-02 | P1 | Cross multiple achievement thresholds in one session, quit/relaunch, then reconnect Steam after earning one while offline. | Notifications do not block play; all in-game values persist and Steam reconciles without duplicates or lost progress. |

## Input, pause, focus, display, and audio

| ID | Gate | Setup / action | Expected result |
| --- | --- | --- | --- |
| INP-01 | RB | Rebind every exposed action one at a time, including movement/navigation, pause, speed, tower actions, and both ability slots. Test duplicate/reserved/invalid keys, reset defaults, quit, and relaunch. | Capture/cancel/conflict behavior is clear; displayed glyphs update; each action fires once; bindings persist and defaults restore without leaving an inaccessible action. |
| INP-02 | RB | With a supported controller, cold-launch and navigate main/campaign/settings/pause/victory/defeat; start and play a run, place/select/upgrade/sell towers, activate/cancel abilities, and hot-plug/reconnect during menu and play. | Correct focus/glyphs and single actions; all required functions are reachable without mouse; disconnect does not hang or lose progress; keyboard/mouse takeover works. |
| PAUSE-01 | RB | Pause/resume by binding and menu during normal wave, boss, active ability, target preview, and between waves; open settings and return. | Simulation, timers, spawns, projectiles, effects, audio state, and input stop/resume consistently; no free charge/income, skipped time, or duplicated input. |
| PAUSE-02 | RB | Alt-Tab/change focus during the same states; hold a key/button while losing focus and release it before returning. Repeat with Steam overlay. | Focus loss follows intended pause policy, no stuck input or elapsed simulation burst occurs, audio follows policy, and display/controller remain responsive on return. |
| DSP-01 | RB | Toggle windowed/fullscreen repeatedly from menu, pause, and active play; Alt-Enter if supported. Drag-resize window to minimum and several intermediate sizes; move between monitors with different scale/refresh settings. | Mode persists as intended; no crash, black screen, off-screen dialog, clipped required control, incorrect pointer mapping, or gameplay-state reset. |
| DSP-02 | RB | Test supported **16:9** at 1280x720 and 1920x1080, and **16:10** at 1280x800 (plus each resolution advertised on the store page/release requirements). Exercise dense HUD, shop, tooltips, settings, recaps, and boss UI. | Entire UI remains readable/reachable without overlap or unsafe cropping; world/pointer scaling is correct and aspect changes reveal no unintended playfield advantage. Any newly advertised aspect/resolution gets its own result row. |
| AUD-01 | RB | Independently set music and SFX to 0%, mid, and 100%; exercise menu, combat, boss, pause, victory, defeat, focus loss, and relaunch. Rapidly adjust sliders and change output device if supported. | Each slider affects only its channel, mute is silent, levels persist, transitions do not pop/double/play stale tracks, and device/focus recovery is graceful. |

## Steam integration and offline operation

| ID | Gate | Setup / action | Expected result |
| --- | --- | --- | --- |
| STM-01 | RB | Launch from Steam online. Open/close overlay from menu, active wave, paused game, victory, and defeat; use a store/community link if present. | Overlay opens above the game, input/simulation follows pause policy, focus/audio recover, link targets are correct, and no held input reaches gameplay on close. |
| STM-02 | RB | Put Steam in Offline Mode, disconnect network, reboot client, and launch the already installed RC. Start/finish a run, earn local progress/achievement, clean quit, relaunch offline, then reconnect. | Game launches and plays without network, shows no blocking retry/hang, saves locally, and later reconciles supported stats/achievements without loss or duplicate rewards. |
| STM-03 | P1 | Verify rich presence in menu, campaign wave/boss, pause, victory/defeat, and after quit. | Presence is timely and accurate, contains no stale/private data, and clears on clean shutdown. |

## Soak and minimum-hardware performance

Use the release's published minimum target hardware. Start from a cold boot with
release-like background services. Record resolution, quality/settings, FPS cap,
average/1% low FPS, worst frame time, peak RAM/VRAM, CPU/GPU utilization and
temperature, save growth, and any hitch/crash. Attach the capture. Unless the
release requirements define stricter thresholds, the gate is stable cap delivery
(60 FPS at the minimum supported 1280x720), 1% low at least 54 FPS, no sustained
frame times above 33.3 ms, no unbounded memory/save growth, and no thermal crash.

| ID | Gate | Duration / action | Expected result |
| --- | --- | --- | --- |
| PERF-01 | RB | On minimum hardware at 1280x720, play a representative late campaign wave and every boss with a dense six-tower build, projectiles/effects, damage meter, and abilities. Capture at least 10 minutes including a worst-case burst. | Meets thresholds; input remains responsive; simulation speed, audio, UI, and enemy/path behavior remain correct under load. |
| SOAK-02 | RB | For at least **100 cycles**, alternate active-run Restart, defeat Restart, victory/menu continuation, and return-to-menu/start; vary map/difficulty and include pause/settings every tenth cycle. Relaunch packaged game every 25 cycles. | Every cycle begins cleanly; no retained enemies/effects/charge/stats, duplicate handlers/music, navigation failure, progression duplication, memory trend, crash, or corrupted save. |
| PERF-02 | P1 | Repeat `PERF-01` in fullscreen native resolution on each minimum-supported platform and compare to the last released build using the same capture. | No material unexplained regression; any accepted regression has a linked defect/waiver and updated published requirements if necessary. |

## Sign-off

| Role | Name | Date | Packaged build | Decision / link |
| --- | --- | --- | --- | --- |
| QA owner | | | | |
| Engineering owner | | | | |
| Release owner | | | | |

The release owner must confirm that the artifact hash above is the artifact being
tagged, every `RB` execution row is `Pass`, all required platforms and advertised
display modes are represented, and every remaining defect has an explicit
non-blocking disposition. Any rebuild invalidates sign-off and requires a new
matrix run appropriate to the changed package.
