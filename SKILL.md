---
name: windows-disk-cleanup
description: Windows（中文环境）磁盘/存储空间清理检测与执行技能。当用户提到"帮我分析/清理/释放磁盘空间"、"C盘/D盘/某个盘满了"、"看看哪里占用大"、"删除/清理缓存、临时文件、大文件、重复文件、安装包残留、*-updater更新缓存"、"清理XX文件夹"、"磁盘空间分析" 或任何要求检查某个磁盘/目录里有什么可删除内容的请求时使用——即使没有明确说"磁盘清理"也应主动启用，也适用于 disk/space/storage/cleanup 等英文表述。技能内置 Windows 环境实测有效的高性能扫描方法与关键约束（含沙箱/受限环境的注意事项），默认执行只读空间分析并产出结构化中文 Markdown 报告；仅在用户明确要求删除、并对每个项目逐项确认后，才进入受控删除流程；可在 WorkBuddy / Claude Code / 其他 Agent / 本地终端中使用。
version: 1.0.1
---

# windows-disk-cleanup — Windows 磁盘空间分析与清理

Detect what is occupying disk space on Windows, produce a structured Chinese Markdown report, and — only
after explicit per-item user confirmation — perform supervised deletions.

The value of this skill is the environment-specific knowledge it encodes (verified empirically), not
generic disk-cleanup advice. **Read the references before starting any scan.**

## 运行环境与路径约定（跨宿主通用）

本技能**不绑定特定宿主**：WorkBuddy / Claude Code / 其他 Agent / 用户本地终端均可使用。请遵守：

- **路径不写死**：扫描目标与报告输出位置一律由用户指定，或使用宿主的当前工作目录；文档与脚本示例中
  一律用占位符（如 `<输出目录>\scan.txt`），**禁止硬编码某台机器的绝对路径**。
- **能力探测与降级**：不同宿主提供的工具不同，缺失时按下表降级，**不要因缺工具而拒绝执行**。

| 能力 | 用途 | 缺失或不同时 |
|---|---|---|
| PowerShell 工具 | 磁盘扫描（推荐） | 用 Bash / CMD 调 `powershell -NoProfile -Command ...` |
| 后台任务 | 长耗时扫描 | 改为前台分批执行，或把脚本交给用户自行运行 |
| Read 工具 | 读取结果文件 | 用 `Get-Content` 把内容直接输出到对话 |
| 文件呈现工具（如 `present_files`） | 展示报告 | 直接给出报告路径，或把 Markdown 正文输出到对话 |
| 选择题工具（如 `AskUserQuestion`） | 删除前确认 | 输出可复制的编号选项，请用户回复编号 |
| 计算机管理 API（CIM / 注册表 / COM） | 交叉校验 | 受限时跳过该校验并在报告中标注「未校验」 |

- **删除安全（任何环境都不变）**：只读分析 → 用户逐项确认 → 分批删除 → `Test-Path` 逐项验证。

## Files (read in this order)

| File | When to read |
|---|---|
| `references/environment.md` | **Always, first.** 通用命令模式 + 高效扫描写法 + 受限环境（如 WorkBuddy 沙箱）实测约束。 |
| `references/classification.md` | When classifying what is deletable. What is safe vs traps (registry InstallLocation = app install root; chat/db data; "duplicate"-looking but normal structures; process locks). |
| `references/report-template.md` | When writing the report / deletion summary. |
| `scripts/measure_dirs.ps1` | When measuring directory sizes (run it; pure ASCII; 路径用参数传入). |

## Two modes

1. **Read-only analysis (default).** Scan target disk/folder, produce the report. Never modify/move/delete.
2. **Confirmed deletion.** Only when the user explicitly asks to delete. Follow the confirmation &
   batch/verify flow below. Never delete on vague or unconfirmed requests.

Safety first: chat history (WeChat/QQ), databases, browser profiles, running app installs are NOT
deletable. Every suggestion must be tagged 可删 / 需确认 / 勿动 and decisions left to the user.

## Mode 1 — Read-only analysis workflow

1. **Scope** (ask if unclear): target drive/folder, exclude dirs, depth. `Test-Path` to confirm existence.
2. **Drive overview** (fast): `Get-Volume -DriveLetter X` → 记录总量/剩余。
   若宿主**拿不到 stdout**（见 environment.md），把结果写入工作目录文件再读回；有 stdout 时直接读输出。
   同时读取根目录隐藏文件（`Get-ChildItem 'C:\' -Force -File`）以获取 hiberfil/pagefile/swapfile 大小。
3. **Top-level recursive sizing**: measure each top-level dir (exclude `$RECYCLE.BIN`,
   `System Volume Information`, user excludes) with `scripts/measure_dirs.ps1` (or inline equivalent).
   大根目录可能耗时 10-30+ 分钟 → 有后台能力就后台跑并增量写文件、中途读部分结果；无后台能力则前台分批。
   中文目录名在部分宿主后台任务中会乱码，处理办法见 environment.md。
4. **Category spot-checks** (targeted): Temp, `*-updater` caches, recycle bin, browser cache,
   Windows update cache, hiberfil, big media/installers, duplicates, `.lnk` targets. See
   references/classification.md for the full list and the traps.
5. **Cross-check before judging**: running processes (`Get-CimInstance Win32_Process` by ExecutablePath),
   registry InstallLocation, AVD `.ini` registration, etc. (受限时标注未校验)。
6. **Report** → 写入宿主工作目录的 Markdown 文件；宿主有文件呈现能力就展示，否则给出路径或把报告正文输出到对话。
   删除只在用户后续明确要求时进行。

## Mode 2 — Confirmed deletion workflow

1. Show a table of planned deletions (path | size | rationale) with a bold risk note.
2. 用宿主的选择题工具确认（多选分组 OK；无该工具时输出编号选项请用户回复）。可能丢失用户数据时再确认一次。
3. Check process locks first; only stop processes (with user consent; warn about unsaved data) whose
   ExecutablePath is under the folders to delete.
4. Delete in batches ≤10 dirs: `Remove-Item -LiteralPath <p> -Recurse -Force`, then immediately
   `Test-Path` to record `remaining=` for each.
5. **Noise errors are environment-dependent**: 在带「安全删除」包装的环境中，
   `SAFE_DELETE_FAIL_CLOSED` / "无法找到指定文件" / "Some operations were aborted" 等输出**不代表失败**——
   始终以 `Test-Path` 为准。真正的失败（超大目录等）→ 给出用户可在自己的资源管理器/终端执行的确切命令。
6. Report results: deleted table, failures + manual commands, recycle-bin & freeing note.

## Triggering & boundaries

- A direct request to delete one clearly-understood folder still needs one explicit confirmation (path+reason).
- WeChat/QQ/chat data, browser `User Data`, DB/Redis data dirs, 以及**助手运行时目录**（如 `.workbuddy`、
  `.claude`、`~/.codex` 等，视当前宿主而定）：只给软件内清理建议，绝不给出直接删除方案。
