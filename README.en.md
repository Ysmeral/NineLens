<div align="center">

# NineLens

**A cheat for *Nine-Ball Roulette* — an in-process GDScript mod**

Aim lines · pot prediction · recommended shots · one-key shooting

`by.Ysmeral` · V1.0

**English** · [简体中文](README.md)

</div>

---

## ⚠️ Important notice — read first

> **1. This project is discontinued. There will be no further updates.**
> Once the game changes (node names, interfaces), this project simply stops working.
> The author will not port it to new game builds.
>
> **2. This project exists solely for AI jailbreak testing and technical research.**
> Its purpose is to test how large language models behave on boundary requests such as
> "write me a game cheat". It is not intended for promotion, sale, or distribution as a game cheat.
>
> **3. If this project infringes the rights of the game's developer or publisher, it will be taken down entirely.**
> On any request from a rights holder, this project — source code, documentation and release
> packages — will be removed immediately. This project is not affiliated with, endorsed by, or
> authorised by the developers or publishers of *Nine-Ball Roulette*.
>
> **4. Use at your own risk.**
> Using it in multiplayer may result in account penalties; the user bears full responsibility.

---

## What it is

NineLens is an aiming assistant that runs **inside** the *Nine-Ball Roulette* process.

It is not a memory patcher and it does not read the screen. It uses **Godot's built-in `override.cfg` autoload mechanism** to load a `.gd` script into the running game, which gives direct access to:

- Exact position and number of every ball (`Global.ball_spawn_root`)
- Position and radius of all six pockets (`Table/PocketArea`)
- The cue ball (`Global.cue_ball`)
- The game's own shot function (`Global.shoot(speed)`)

With real data in hand, everything else is plain geometry, projected onto the screen.

> No game file, save file, or DLL is modified. Uninstalling = deleting the two files placed in the game folder.

---

## Features

| Feature | Description |
|---|---|
| **Aim line** | Draws from the cue ball along your current aim to the true contact point, then continues along the object ball's departure direction |
| **Pot prediction** | Tells you in real time whether the shot goes in, with an angular tolerance (±x°) |
| **Recommended shot** | Searches every makeable ball, marking the target, the pocket, and the ghost ball |
| **One-key shot** | `F8` picks the ball, picks the power, and corrects direction after the shot — the cue does not need to be aligned |
| **Recommendation toggle** | `G` hides every recommendation element, leaving only your own aim line |

---

## Installation

1. Download and extract `NineLens_V1.0.zip`
2. Close the game completely
3. Run `安装.bat` (Install)
   - It scans drives C–J for the Steam library automatically
   - If not found, drag the game folder onto `安装.bat`
4. Launch the game — `NineLens V1.0 已加载` appears at the top-left

### Uninstall

Run `卸载.bat` (Uninstall), or delete these two files from the game folder:

```
override.cfg
nbr_cheat.gd
```

**If the uninstaller fails** (permission denied, file in use, game folder not found),
hand the game folder to an AI agent (Claude Code / Codex / DeepSeek Harness / Cursor, etc.)
and let it delete the two files above — it is a plain file deletion, no command line knowledge needed.

---

## Keys

| Key | Action |
|---|---|
| `F5` | Toggle HUD |
| `F6` | Toggle aim lines |
| `F7` | Select the recommended target and show its details |
| `F8` | Shoot |
| `G` | Toggle recommendation |
| `T` | Cycle target ball |
| `B` | Cycle pocket |
| `[` `]` | Power −0.5 / +0.5 |
| `\` | Power back to auto |

---

## How it works

```
override.cfg [autoload] → load nbr_cheat.gd → same process as the game → read scene tree → geometry → project → draw
```

1. **Read** — ball and pocket coordinates come straight from the Godot scene tree
2. **Solve** — ghost ball from the target-to-pocket line, ray-circle intersection for the true contact point, object ball departs along the line of centres
3. **Predict** — the departure line must pass within 0.85 × pocket radius, with both paths unobstructed
4. **Draw** — `Camera3D.unproject_position` maps 3D points to the screen, drawn on a CanvasLayer
5. **Shoot** — `Global.shoot(power)`, then the cue ball's velocity is re-aimed (magnitude preserved)

See [docs/原理讲解.md](docs/原理讲解.md) for a beginner-friendly walkthrough (Chinese).

---

## Repository layout

```
NineLens/
├── src/nbr_cheat.gd        Main script (the only file that goes into the game)
├── installer/              One-click install / uninstall (bat + notes)
├── docs/                   User manual, how-it-works
├── tools/                  Static checks, release builder
├── README.md               Chinese
├── README.en.md            English
├── CHANGELOG.md
└── LICENSE
```

---

## Building from source

```bash
python tools/gdcheck.py src/nbr_cheat.gd     # brackets / indentation / block headers
python tools/gdident.py src/nbr_cheat.gd     # undeclared identifiers
python tools/build_release.py                # produces dist/NineLens_V1.0.zip
```

`build_release.py` reads the version from `src/nbr_cheat.gd` and refreshes the version string and checksum in `installer/说明.txt`.

---

## Compatibility

- Supports *Nine-Ball Roulette* build **1.1.5 (Godot 4.6.1)** only
- **No new versions will be supported** — node names may change after a game update and this project will stop working
- In multiplayer the lines are drawn locally and are not synced to other players

---

## Known limitations

Pot prediction is **geometric** and ignores:

- Cue ball spin (english / draw / follow)
- Cushion energy loss
- Throw (friction between balls)

So "can pot" means geometrically possible; heavy spin or an extremely thin cut may still rattle.

---

## License

[MIT](LICENSE) © 2026 Ysmeral

---

<div align="center">

**by.Ysmeral**

</div>