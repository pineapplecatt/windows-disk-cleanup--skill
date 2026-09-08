---
name: windows-disk-cleanup
description: Windows（中文环境）磁盘/存储空间清理检测与执行技能。当用户提到"帮我分析/清理/释放磁盘空间"、"C盘/D盘/某个盘满了"、"看看哪里占用大"、"删除/清理缓存、临时文件、大文件、重复文件、安装包残留、*-updater更新缓存"、"清理XX文件夹"、"磁盘空间分析" 或任何要求检查某个磁盘/目录里有什么可删除内容的请求时使用——即使没有明确说"磁盘清理"也应主动启用，也适用于 disk/space/storage/cleanup 等英文表述。技能内置在 WorkBuddy Windows 沙箱环境实测有效的全部方法与关键环境约束（PowerShell 无 stdout、Bash 读限、删除被"安全删除"包装等），默认执行只读空间分析并产出结构化中文 Markdown 报告；仅在用户明确要求删除、并对每个项目逐项确认后，才进入受控删除流程。
---

# windows-disk-cleanup — Windows disk space analysis & cleanup (WorkBuddy)

Detect what is occupying disk space on Windows in a WorkBuddy (sandboxed) environment, produce a
structured Chinese Markdown report, and — only after explicit per-item user confirmation — perform
supervised deletions.

The value of this skill is the environment-specific knowledge it encodes (verified on this machine),
not generic disk-cleanup advice. **Read the references before starting any scan.**

## Files (read in this order)

| File | When to read |
|---|---|
| `references/environment.md` | **Always, first.** Environment constraints & command patterns (PowerShell no stdout → write to file; sandbox limits; blocked APIs; safe-delete wrapper behavior; recycle-bin per drive; background mojibake; big-dir delete limit). |
| `references/classification.md` | When classifying what is deletable. What is safe vs traps (registry InstallLocation = app install root; chat/db data; "duplicate"-looking but normal structures; process locks). |
| `references/report-template.md` | When writing the report / deletion summary. |
| `scripts/measure_dirs.ps1` | When measuring directory sizes (run it; pure ASCII). |

## Two modes

1. **Read-only analysis (default).** Scan target disk/folder, produce the report. Never modify/move/delete.
2. **Confirmed deletion.** Only when the user explicitly asks to delete. Follow the confirmation &
   batch/verify flow below. Never delete on vague or unconfirmed requests.

Safety first: chat history (WeChat/QQ), databases, browser profiles, running app installs are NOT
deletable. Every suggestion must be tagged 可删 / 需确认 / 勿动 and decisions left to the user.

## Mode 1 — Read-only analysis workflow

1. **Scope** (ask if unclear): target drive/folder, exclude dirs, depth. `Test-Path` to confirm existence.
2. **Drive overview** (foreground, fast): `Get-Volume -DriveLetter X` → write totals to a workspace file.
   Also read hidden root files (`Get-ChildItem 'C:\' -Force -File`) for hiberfil/pagefile/swapfile sizes.
3. **Top-level recursive sizing** (background): measure each top-level dir (exclude `$RECYCLE.BIN`,
   `System Volume Information`, user excludes) with `scripts/measure_dirs.ps1` (or inline equivalent).
   Large roots can take 10-30+ min → run background, write incrementally, read partial results.
   See references/environment.md for mojibake/ordering caveats.
4. **Category spot-checks** (foreground, targeted): Temp, `*-updater` caches, recycle bin, browser cache,
   Windows update cache, hiberfil, big media/installers, duplicates, `.lnk` targets. See
   references/classification.md for the full list and the traps.
5. **Cross-check before judging**: running processes (`Get-CimInstance Win32_Process` by ExecutablePath),
   registry InstallLocation, AVD `.ini` registration, etc. (references/classification.md).
6. **Report** → write Markdown to workspace, present_files. Deletion happens only in a later turn on the
   user's explicit request.

## Mode 2 — Confirmed deletion workflow

1. Show a table of planned deletions (path | size | rationale) with a bold risk note. 
2. AskUserQuestion to confirm (multi-select groups OK). Re-confirm when user data could be lost.
3. Check process locks first; only stop processes (with user consent; warn about unsaved data) whose
   ExecutablePath is under the folders to delete.
4. Delete in batches ≤10 dirs: `Remove-Item -LiteralPath <p> -Recurse -Force`, then immediately
   `Test-Path` to record `remaining=` for each.
5. **Noise errors are expected**: `SAFE_DELETE_FAIL_CLOSED` / "无法找到指定文件" / "Some operations were
   aborted" prints do NOT mean failure — always verify by Test-Path. Genuine failures (large dirs) → give
   the user exact commands to run in their own Explorer/terminal.
6. Report results: deleted table, failures + manual commands, recycle-bin & freeing note.

## Triggering & boundaries

- A direct request to delete one clearly-understood folder still needs one explicit confirmation (path+reason).
- WeChat/QQ/chat data, browser `User Data`, DB/Redis data dirs, `.workbuddy` runtime: give in-app cleanup
  guidance only — never direct deletion advice.
