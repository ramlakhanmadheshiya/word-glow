# Word Lantern

*A calm word-light puzzle.* Every tile in the grid belongs to one hidden word on the level's theme. Drag through neighbouring letters to find each word, and it lights up like a string of paper lanterns. Light every tile to clear the level.

Made with Godot 4.7.2 (GDScript, Compatibility renderer, so it also runs on the web). Portrait-first; works with touch, mouse and keyboard.

**Play / download:** https://theramlakhan.com/word-lantern/ (browser version and Android APK)
**Made by:** [Ramlakhan Madheshiya](https://theramlakhan.com), with Claude as AI co-developer.

## The game

- **Fill-the-grid word finding.** Each level is a theme (*Fruit*, *Weather*, *Castle*…) and a grid covered completely by its hidden words, traced up, down, left or right. The slots above the grid show each word's length.
- **Every answer fits in exactly one place.** The level checker rejects any level where a word could be spelled along another path.
- **Shadow tiles** (from chapter 3) hide their letters until a word next to them is found. **Beacons** (from chapter 5) light their whole row and column.
- **16 chapters × 40 levels = 640 levels.** Each chapter has its own colours and follows the same curve:

  | Levels | Difficulty | Grid (early → late chapters) | Words |
  |---|---|---|---|
  | 1–5 | Easy | 4×4 → 5×4 (chapter 1 starts on 3×3) | 3–5 letters |
  | 6–10 | Easy–medium | 5×4 → 5×5 | 3–6 |
  | 11–20 | Medium | 5×5 → 6×5 | 4–6 |
  | 21–30 | Medium–hard | 6×5 → 6×6 | 4–7 |
  | 31–39 | Hard | 6×6 → 7×6 | 5–7 |
  | 40 | Extreme | 8×7, long words only | 6–8 |

  Later chapters sit higher on the curve (bigger grids sooner, longer words, more shadows and beacons). `tests/levels_test.gd` checks that every tier is harder on average than the one before and that level 40 is the hardest level of its chapter.
- **Three stars.** A perfect solve (no wrong words, no hints) earns ★★★; up to 3 extra moves earns ★★; more earns ★. A MOVES / STARS strip over the board shows what is still on offer, like Single Shot's TRY / STARS.
- **Progress:** levels open one at a time; clearing 15 levels in a chapter opens the next. A level key opens any locked level early. Locked levels are still shown on the level grid.
- **Daily lantern:** one puzzle a day for everyone, from a pool of 730 pre-made, solver-checked puzzles (`data/levels/daily.json`). The day's puzzle is *days since 1 Oct 2026, modulo 730*, using the device's local date, so no daily repeats before October 2028; neighbouring days never share a theme. It works offline.
- **Rewards** (each paid once): +5 coins for a first clear, +5 for every new star, +100 and an achievement for finishing a chapter, +30 (plus a streak bonus) for the daily lantern, and 32 achievements in all.
- **Hints:** *Spark* (25 coins) reveals the next letter of a word; the first Spark each day is free (3 for Supporters). *Lantern* (60 coins) finds a whole word. **Out of coins, the player can watch a rewarded video for the hint.** Hints count as extra moves.
- **Shop** (Single Shot's model; one-time packs plus consumables, all via Google Play):

  | Product | What it gives |
  |---|---|
  | Complete pack | Everything below, plus 1,000 coins and 5 level keys |
  | Supporter pack | No banner ads, 3 free Sparks a day |
  | Theme pack | 11 colour themes for sky and tiles (1-hour trial from a video) |
  | Lantern styles | 6 styles for lit words and tiles (1-hour trial from a video) |
  | Coin bags | 300 / 1,000 / 2,500 / 6,000 coins; plus free coins from a video (5 a day) |
  | Level keys | 1–10 keys, 10% off for 5+; plus a free key from a video (5 a day) |
  | Tip jar | Say thanks; unlocks nothing |

  Product ids and Play Console setup: [`store/PLAY_PRODUCTS.md`](store/PLAY_PRODUCTS.md). Debug desktop builds simulate purchases; the web build explains that purchases are in the Android app.
- **Ads (Android):** a banner at the bottom of the home, chapters, levels, shop and game screens, with layout space reserved so it never covers a button; rewarded videos only when the player asks. No interstitials. Supporters see no banners. The web build shows no ads (where no video can be shown, an out-of-coins hint is simply free).
- **Settings:** Music and Sound volume sliders, Vibration, colour theme and lantern style pickers, How to play, Shop, Awards, About, Credits, Ad privacy (when required), and Reset progress (like Single Shot: tap once to arm, again to erase; hidden during a level; keeps settings, packs, keys and bought coins).
- **While playing,** MOVES / STARS stay visible at the top; the letters being traced and short messages appear on their own line just above the board.
- **Saving:** everything is saved locally with atomic writes and a backup; half-played levels resume; version-1 saves are migrated.

### Controls

| Input | Action |
|---|---|
| Drag (touch or mouse) | Trace a word; slide back to undo the last letter |
| H | Spark hint |
| R | Restart the level |
| Esc / Android Back | Back (level → levels → chapters → home) |

## Run

```sh
./play.sh              # launches the game window directly (no editor)
```

Debug desktop runs show a test ad banner and simulate purchases, so every flow can be tried without a phone.

## Test

```sh
./tests/run_all.sh
```

| Suite | What it checks |
|---|---|
| `tests/levels_test.gd` | 61 themes of valid words; all 1,370 levels (640 + 730 daily): full coverage, adjacent paths, theme words only, no duplicates, each answer traceable in one place only, solvable with shadows, played through with the real game logic; the difficulty curve of every chapter; mechanics only from their chapters. |
| `tests/logic_test.gd` | Word validation, shadows, beacon beams, hints, stars and moves, save/restore of half-played levels, and broken puzzles the validator must reject. |
| `tests/profile_test.tscn` | Coins, free Sparks, stars and star rewards, unlocks, keys, chapter bonus, dailies, achievements (once), video reward limits, simulated purchases (packs, coins, keys, tips), trials, reset keeping purchases, restart persistence, corrupt-save recovery, v1 migration. |
| `tests/ui_flow.tscn` | The real app end to end with the mock ad provider: banner space, chapters, 40-tile level grid with locked levels, a level with a wrong guess (2★), Again for 3★, Next, a locked level opened with a key, free/paid hints, out-of-coins video (watched and skipped), Restart, the shop (coin bag, free coins video, pack trial, theme pick, Supporter removes the banner), volume sliders, Reset hidden in a level, the daily, and an app restart. |
| Boot smoke | Runs the game for 300 frames and fails on any error, warning or leak. |

Screenshots of every screen (needs a display; add `clean` to hide the test banner):

```sh
godot --path . res://tests/capture.tscn -- /tmp/wl_shots 390 844
```

## Make the levels

```sh
godot --headless --path . -s res://tools/generate_levels.gd            # everything
godot --headless --path . -s res://tools/generate_levels.gd -- canyon  # one chapter
```

Levels are generated once from `data/themes.json` and the plan in `data/chapters.json`, and committed. The generator is deterministic (CI regenerates and fails on any difference). For each level it builds a random Hamiltonian path over the grid, cuts it into theme words, rejects layouts where an answer can be traced elsewhere, and places shadows and beacons only where every tile can still be lit, light spreads in waves, and beacons genuinely help.

## Build & publish

Every push to `main` runs `.github/workflows/build.yml`: tests, the reproducibility check, a web export, a signed Android APK (Gradle build with the AdMob and Play Billing plugins), publishing to `gh-pages` (served at `https://theramlakhan.com/word-lantern/` with `play/`, `help/`, `privacy/` and `word-lantern.apk`), and an `.aab` artifact for Google Play.

Repository secrets:

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEYSTORE_ALIAS` | Release signing (without them a throwaway key is used, and updates can't install over older builds) |
| `ADMOB_APP_ID`, `ADMOB_BANNER_ID`, `ADMOB_REWARDED_ID` | Real AdMob units (without them Google's test ads are used) |

## Project structure

| Path | What it holds |
|---|---|
| `game/core/` | Pure logic: `puzzle.gd`, `rules.gd` (light, paths, solver, validator), `level_state.gd` (a level in play: tracing, hints, moves, stars), `economy.gd` (prices, rewards, star rule), `achievements.gd` |
| `game/autoload/` | `save.gd` (versioned JSON save), `catalog.gd` (chapters, tiers, levels, daily), `profile.gd` (coins, stars, unlocks, keys, purchases, trials, streaks, achievements, settings), `store.gd` (catalogue and Play Billing), `audio.gd`, `haptics.gd` |
| `game/ads/` | `ad_manager.gd` (banner and rewarded policy) and providers: AdMob (Android) and a mock (debug desktop, tests) |
| `game/board/` | `board_view.gd` (grid, drag input, animations), `word_list.gd` |
| `game/ui/` | `app.gd` (screens, Back chain, overlays, toasts, loading/error states), `screen.gd` (header, banner space), `overlay.gd`, `ui_kit.gd`, `style.gd`, `look.gd` (themes and lantern styles), `screens/` (home, chapters, levels, play, shop), `overlays/` (settings, result, product, picker, keys, tips, locked, how-to, about, credits, achievements, messages), `widgets/` |
| `data/` | `themes.json`, `chapters.json`, `levels/` |
| `addons/` | Godot AdMob plugin (Poing Studios, MIT) and Godot Google Play Billing (MIT) |
| `store/` | Play Console product list |
| `tools/`, `tests/`, `web/` | Generators, tests and the website pages |

## Credits

| Asset | Source | Licence |
|---|---|---|
| Engine: [Godot Engine](https://godotengine.org) 4.7.2 | Godot contributors | MIT |
| Font: [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit) | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL.txt` |
| UI icons: [Lucide](https://lucide.dev) | lucide-static 0.460.0 | ISC, `assets/icons/LICENSE.txt` |
| Game icons and the app icon | Drawn for Word Lantern | Released with the project |
| Music and sound effects | Generated by `tools/synth_audio.py`, no samples | Released with the project (CC0) |
| Theme word lists and levels | Curated for Word Lantern | Released with the project |
| [Godot AdMob Plugin](https://github.com/poingstudios/godot-admob-plugin) | Poing Studios | MIT, `addons/admob/LICENSE` |
| [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) | Godot contributors | MIT, `addons/GodotGooglePlayBilling/LICENSE` |

Game design and development: **Ramlakhan Madheshiya** — https://theramlakhan.com
