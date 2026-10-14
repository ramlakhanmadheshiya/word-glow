# Word Lantern

*A calm word-light puzzle.* Every tile in the grid belongs to one hidden word on the level's theme. Drag through neighbouring letters to find each word, and it lights up like a string of paper lanterns. Light every tile to clear the level.

Made with Godot 4.7.2 (GDScript, Compatibility renderer, so it also runs on the web). Portrait-first; works with touch, mouse and keyboard.

**Play / download:** https://theramlakhan.com/word-lantern/ (browser version and Android APK)
**Made by:** [Ramlakhan Madheshiya](https://theramlakhan.com), with Claude as AI co-developer.

## The game

- **Fill-the-grid word finding.** Each level is a theme (*Fruit*, *Weather*, *Castle*…) and a grid covered completely by its hidden words. Words are traced up, down, left or right (never diagonally) and read in the order you trace. The slots above the grid show how many words there are and how long each is.
- **Every answer fits in exactly one place.** The level checker rejects any level where a word could be spelled along another path, so a correctly spelled answer is never refused for being "in the wrong spot".
- **Shadow tiles** (from World 2): dark tiles hide their letters until a word next to them is found. The light spreads, so the order you solve in matters.
- **Beacons** (from World 4): flame tiles that, when their word is found, beam light along their whole row and column.
- **8 worlds × 20 levels = 160 levels,** growing from 3×3 grids with 3-letter words to 7×8 grids with long words, many shadows and several beacons:

  | # | World | Grid | Words | New |
  |---|---|---|---|---|
  | 1 | Meadow | 3×3 → 4×5 | 3–5 letters | the basics (with a guided first level) |
  | 2 | Harbor | 4×5 → 5×6 | 3–6 | shadow tiles from level 6 |
  | 3 | Orchard | 5×5 → 5×6 | 4–7 | more shadows |
  | 4 | Canyon | 5×6 → 6×6 | 4–7 | beacons |
  | 5 | Glacier | 6×6 → 6×7 | 4–7 | two beacons |
  | 6 | Bazaar | 6×7 | 4–8 | deeper shadows |
  | 7 | Aurora | 6×7 → 7×7 | 5–8 | |
  | 8 | Starfall | 7×7 → 7×8 | 5–8 | up to 22 shadows, 3 beacons |

- **Progress:** levels open one at a time; clearing 15 levels in a world opens the next.
- **Daily lantern:** a new puzzle each day (from a pool of 120), with a streak bonus.
- **Hints and coins:** *Spark* (25 coins) reveals the next letter of a word, and the first Spark each day is free. *Lantern* (60 coins) finds a whole word. Coins come from first clears (+10, +5 without hints), finishing a world (+50), dailies (+30, +5 per streak day up to +60) and 13 achievements. Every reward is keyed to what earned it and paid once; replays pay nothing.
- **Saving:** progress, coins, settings, daily status and even half-finished levels are saved locally (atomic writes with a backup copy; a corrupt save is recovered from the backup).
- **No ads, no accounts, no network.** Fully offline.

### Controls

| Input | Action |
|---|---|
| Drag (touch or mouse) | Trace a word; slide back to undo the last letter |
| H | Spark hint |
| Esc / Android Back | Pause in a level, close a card, go back |

## Run

```sh
./play.sh              # launches the game window directly (no editor)
```

Or open `project.godot` in Godot 4.7.2 and press Play. Without the `godot` command on your PATH, set `GODOT=/path/to/Godot`.

## Test

```sh
./tests/run_all.sh
```

Runs headless and prints one line per suite:

| Suite | What it checks |
|---|---|
| `tests/levels_test.gd` | Every theme word is A–Z, 3+ letters, unique in its theme; every one of the 280 levels (160 + 120 daily) covers each tile exactly once with adjacent paths, uses only its theme's words, has no duplicate answers, has each answer traceable in only one place, can be fully lit despite shadows, and is played through with the real game logic (reversed words refused, every word accepted in solve order). Difficulty never steps backwards within a world. |
| `tests/logic_test.gd` | Word validation (too short, wrong word, reversed, jumps, revisits, already found), shadows, beacon beams, hints, saving and restoring half-played levels; plus deliberately broken puzzles that the validator must reject. |
| `tests/profile_test.tscn` | Coins can't go negative, rewards and achievements pay once, unlock rules, daily streaks, restart persistence, and recovery from corrupt saves. |
| `tests/ui_flow.tscn` | The real app end to end: menus, locked worlds/levels, a full level with a wrong guess, result card and reward, Next, Pause, resume, hints (free/paid/unaffordable), replay pays nothing, the daily, and an app restart. |
| Boot smoke | Runs the game for 300 frames and fails on any error or warning. |

Screenshots of every screen at any window size (needs a display):

```sh
godot --path . res://tests/capture.tscn -- /tmp/wl_shots 390 844
```

## Make the levels

Levels are data (`data/levels/*.json`), generated once from the curated theme word lists (`data/themes.json`) and the plan in `data/worlds.json`:

```sh
godot --headless --path . -s res://tools/generate_levels.gd           # everything
godot --headless --path . -s res://tools/generate_levels.gd -- harbor # one world
```

The generator is deterministic. CI regenerates and fails if the result differs from the committed files. For each level it:

1. builds a random Hamiltonian path over the grid (so every tile is used once) and cuts it into lengths that match the theme's words;
2. rejects the layout if any answer can be traced along a different set of tiles;
3. places shadows and beacons, keeping them only if every tile can still be lit, light has to spread in at least 2–3 waves, at least two words are playable at the start, and each beacon reveals shadows its own word could not reach (and the level is harder without beams).

To add words or themes, edit `data/themes.json`, regenerate, and run the tests.

## Build & publish

Every push to `main` runs `.github/workflows/build.yml`:

1. runs the tests and checks the levels regenerate identically;
2. exports the web build and a signed Android APK with Godot 4.7.2;
3. publishes them to the `gh-pages` branch, which GitHub Pages serves at `https://theramlakhan.com/word-lantern/`:
   - `index.html` is the landing page (from `web/index.html`), with `help/` and `privacy/`;
   - `play/` is the browser version;
   - `word-lantern.apk` is the Android app;
4. builds an Android App Bundle (`.aab`) as a workflow artifact for a future Google Play release.

APK signing uses three repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEYSTORE_ALIAS`. Without them the workflow signs with a throwaway key, and phones then can't install updates over an older version.

## Project structure

| Path | What it holds |
|---|---|
| `game/core/` | Pure game logic, no UI: `puzzle.gd` (level data), `rules.gd` (light spreading, path search, solver, validator), `level_state.gd` (a level in play: tracing, hints, resumable state), `economy.gd` (all prices and rewards), `achievements.gd` |
| `game/autoload/` | `save.gd` (JSON save, atomic writes, backup), `catalog.gd` (worlds, themes, level files, daily selection), `profile.gd` (coins, unlocks, rewards, streaks, achievements, settings), `audio.gd`, `haptics.gd` |
| `game/board/` | `board_view.gd` (grid drawing, drag input, animations), `word_list.gd` (answer slots) |
| `game/ui/` | `app.gd` (screen stack, transitions, overlays, toasts, Back, loading and error states), `screen.gd` / `overlay.gd` base classes, `ui_kit.gd` + `style.gd` (design system), `screens/`, `overlays/`, `widgets/` |
| `data/` | `themes.json` (46 curated themes), `worlds.json` (worlds and generation plan), `levels/` (generated levels) |
| `assets/` | Font, icons, app icon, Android icons, synthesised audio |
| `tools/` | Level generator, audio synthesiser (`synth_audio.py`, stdlib only), icon renderer |
| `tests/` | Test suites and the screenshot tool |
| `web/` | Landing, help and privacy pages for the website |

## Credits

| Asset | Source | Licence |
|---|---|---|
| Engine: [Godot Engine](https://godotengine.org) 4.7.2 | Godot contributors | MIT |
| Font: [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit) | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL.txt` |
| Icons: [Lucide](https://lucide.dev) (UI icons) | lucide-static 0.460.0 | ISC, `assets/icons/LICENSE.txt` |
| Game icons (lantern, coin, flame, sparkles, trophy, calendar, pause, book, restart) and the app icon | Drawn for Word Lantern | Released with the project |
| Music and sound effects | Generated by `tools/synth_audio.py`, no samples | Released with the project (CC0) |
| Theme word lists and levels | Curated for Word Lantern; levels generated by `tools/generate_levels.gd` | Released with the project |

Game design and development: **Ramlakhan Madheshiya** — https://theramlakhan.com
