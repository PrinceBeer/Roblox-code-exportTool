# rbxl-code-export

从 Roblox 场景/模型文件(`.rbxl`)中导出代码,整理成 Rojo 项目,在 VS Code 中编辑。

Export code (Script / LocalScript / ModuleScript) from Roblox `.rbxl` place files and organize it into Rojo projects editable in VS Code.

**Why not remodel?** Remodel is deprecated — its last commit (2023-07-22) reads *"Deprecate remodel in favor of Lune"*, and v0.11.0 is the final release. New Studio saves `.rbxl` with property types (Capabilities / SharedStringBuffer / Tags) and LZ4 compression that remodel 0.11.0 cannot read. Rojo itself only reads XML (`.rbxlx`/`.rbxmx`), not binary `.rbxl`. This project uses **Lune**, the official successor, which reads binary place files perfectly.

## Features

- ✅ Reads binary `.rbxl` (new Studio formats, LZ4 compression included) via [Lune](https://github.com/lune-org/lune)
- ✅ Exports all scripts with hierarchy mirrored: `Script` → `.server.lua`, `LocalScript` → `.client.lua`, `ModuleScript` → `.lua`
- ✅ Scripts with child scripts → `folder/init.<ext>` (Rojo convention)
- ✅ Lightweight containers (ScreenGui / Frame / TextButton / RemoteEvent / Model …) → `<name>.model.json` preserving class name + key properties
- ✅ Auto-generates a **sync-safe** `default.project.json` (only maps containers that can be fully round-tripped, so Rojo sync can't delete unreproducible content)
- ✅ Two modes: manually list files, or auto-scan a folder for all `*.rbxl`
- ✅ Verified with `rojo build` on both test scenes

## Quick Start

1. Install Lune: download `lune-x.y.z-windows-x86_64.zip` from [releases](https://github.com/lune-org/lune/releases), extract `lune.exe`, put it somewhere on `PATH` (China mirror: prefix the URL with `https://ghproxy.net/`).
2. Put `export_scenes.lua` in the folder that contains your `.rbxl` files.
3. Edit the `PLACES` table at the top of `export_scenes.lua` (or set `PLACES = {}` to auto-scan all `.rbxl` in the folder):

```lua
local PLACES = {
	{ file = "MyPlace.rbxl", name = "MyPlace", label = "备注" },
}
```

4. Run:

```
lune run export_scenes.lua
```

5. Output goes to `export/<name>/`:

```
export/MyPlace/
├── src/                    # mirrored instance hierarchy (scripts + model.json)
├── default.project.json    # Rojo project — open with VS Code + Rojo
└── 导出清单.txt              # export manifest (UTF-8)
```

### External control (CLI args)

Pass files as arguments to export only those (paths may be absolute; basename is used as the output folder name):

```
lune run export_scenes.lua -- MyPlace.rbxl "C:\Other\AnotherPlace.rbxl"
```

If no args are given, `PLACES` is used; if `PLACES = {}`, all `*.rbxl` in the current folder are auto-scanned (`SKIP_FILES` excludes files).

## Distribution Package (`dist/`)

The `dist/` folder is a **foolproof, self-contained distribution**: it bundles `lune.exe`, a double-click/drag-and-drop `导出.bat` entry, Chinese instructions, and an **author-controlled auto-update mechanism** (users automatically download the latest `export_scenes.lua` from your `更新源.txt` URL on every run). Recipients need to install nothing. See [`dist/README.md`](dist/README.md).

## Sync Back to Studio — Read This First

Rojo sync **deletes everything inside a mapped container that is not in the project**. The generated project only maps containers that are fully represented (pure code). Containers with heavy content (parts / rigs / UI layout) are exported for reference but **not mapped**, so syncing cannot destroy them.

- Back up your `.rbxl` before syncing.
- UI layout properties (`Position`/`Size`, UDim2/UDim) cannot be expressed in Rojo model.json (Rojo 7.7's `AmbiguousValue` has no object variant) — `StarterGui` is therefore not mapped.
- See `流程.md` (Chinese) for the full workflow, pitfalls and troubleshooting.

## Repository Layout

| File | Purpose |
|---|---|
| `export_scenes.lua` | The export tool (Lune script) |
| `SKILL.md` | Packaged as an AI-agent skill (frontmatter: name / description / whenToUse) |
| `流程.md` | Full workflow guide (Chinese): background, why remodel fails, steps, pitfalls |
| `README.md` | This file |

## License

MIT — see [LICENSE](LICENSE).
