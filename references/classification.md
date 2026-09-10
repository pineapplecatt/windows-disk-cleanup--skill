# Classification guide: deletable vs traps

Use when deciding what a directory/file actually is. When in doubt, mark "需确认" and let the user decide.
Better to under-report than to misreport something as deletable.

## Categories that are usually safe to delete (still confirm with user)

| Category | Typical paths | Note |
|---|---|---|
| System/user temp | `%LOCALAPPDATA%\Temp`, `C:\Windows\Temp`, drive-root `\tmp` | fully clearable; in-use files skip themselves |
| Software updater caches | `AppData\Local\*-updater` (e.g. `cursor-updater`, `coze-updater`, `xmind-updater`, `EpicGamesLauncher`) | old installers downloaded by update apps; apps keep working, re-download on next update |
| Browser cache | Edge/Chrome `User Data\*\Cache`, `Code Cache` | cache subdirs only — NEVER the whole `User Data` (logins/bookmarks/passwords) |
| Windows update cache | `C:\Windows\SoftwareDistribution\Download`, `C:\$WINDOWS.~BT` | prefer 磁盘清理 (cleanmgr); stopping wuauserv not required for Download subfolder |
| Recycle bin | `<drive>:\$RECYCLE.BIN` | confirm contents first; must empty per-drive bin to free space |
| Installer leftovers | setup.exe/.msi caches, old-version folders of an app (e.g. WPS 12.1.0.xxx older than current) | verify current version via registry first; multi-version apps often keep old dirs with running processes |
| Dev build caches | `.gradle`, `.m2`, `.hvigor`, `npm-cache`, `_npx`, VS `.ipch`, `node_modules/.cache` in code projects | deleting is safe but next build re-downloads (slower first build) |
| Crash dumps/logs | `AppData\Local\CrashDumps`, `DumpStack.log.tmp`, stray `.log` at drive root | small but junk |
| Orphaned duplicate copies | e.g. same installer kept in two folders | confirm both copies are truly redundant |

## TRAPS — look-like-junk but must NOT be treated as cache/duplicate

1. **Registry InstallLocation == the real app install.** Query Uninstall keys' `InstallLocation`
   (and `DisplayIcon`). A folder referenced there — even if it sits inside a "download/install manager"
   area like `D:\Download\Assistant` — is the running program's home (百度网盘/搜狗输入法/WPS/Typora/Clash/
   迅雷/飞书/腾讯会议/有道/语雀/向日葵/Gaaiho/EV录屏/7-Zip were all found installed there). Only the pure
   setup.exe/installer files and non-referenced leftovers inside are deletable. Portable/green apps also run
   straight from such folders — check process ExecutablePath before touching.
2. **User data**: WeChat `wechat_files` / QQ data / MemoTrace export dbs / MySQL·Redis data dirs — in-app
   cleanup only, never direct deletion.
3. **Normal "duplicates" that must stay**:
   - Python venv copies of mkl_*.dll/numpy (venv is a self-contained env)
   - node_modules multi-platform binaries (e.g. opencode.exe ×3)
   - a game's 32/64-bit data dirs (The Forest `TheForest_Data` vs `TheForest32_Data`)
   - SDK internal version copies (`...\clang\15.0.4` vs `current`, DevEco fonts, etc.)
   - **Android AVD images**: `userdata-qemu.img`/`ram.img` duplicated across `.android\avd` homes may be two
     independent emulator environments. Before deleting an AVD check (a) its `.ini` registration in the same
     avd dir (no `.ini` = orphan/not listed), (b) which SDK the emulator uses (env `ANDROID_HOME` /
     registry), (c) `config.ini` `image.sysdir` to see which SDK system-images it needs. Only SDK that is
     actually referenced by `ANDROID_HOME` is safe to assume active.
4. **Running processes**: any folder with a live process under its path is locked/in use — skip or close
   the app first (warn about unsaved work).
5. **System areas**: WinSxS, System32, `Windows\Installer` (handle via 磁盘清理/DISM, never manually).
   `pagefile.sys`/`swapfile.sys` managed by OS — never delete. `hiberfil.sys` releases only via
   `powercfg /h off` (admin) and disables hibernation.
6. 助手运行时目录（当前宿主的程序数据目录，例如 `.workbuddy`、`.claude`、`~/.codex` 等，视宿主而定）— do not touch.

## Quick decision procedure per candidate folder
1. Does a process run from it? → 勿动 / close first.
2. Registry Uninstall InstallLocation points at it? → it's the app root → 勿动 (or real uninstall).
3. Contains chat records / database data? → 软件内清理 only.
4. Otherwise (installer exe, old version, pure cache) → candidate, ask user.
