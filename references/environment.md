# Environment constraints & command patterns (verified on this machine)

These are the reason this skill exists. Violating them wastes many turns on broken tooling.

## Constraints

1. **PowerShell tool returns no stdout.** Any visible output from a PS command is lost. ALWAYS accumulate
   lines into `$out = New-Object System.Collections.ArrayList`, then `Set-Content`/`Add-Content` a file
   inside the workspace, then read it with the Read tool.
2. **Bash sandbox cannot read disks outside the workspace.** `du /c/...` on C:/D: returns empty. Use Bash
   only for workspace mkdir/ls. All drive scanning goes through the PowerShell tool.
3. **Blocked APIs** (error: "Command blocked for security"):
   - `Add-Type`, `[Reflection.Assembly]::Load*`
   - COM instantiation: `WScript.Shell`, `Shell.Application` (so you cannot explicitly "send to recycle bin")
   - System tools: `fsutil`, `wmic`, `reg`, `sc`, `schtasks`, and similar
   - Working alternatives: `Get-Volume`, `Get-ChildItem`, read-only `[System.IO.Directory]` APIs,
     `Get-CimInstance Win32_Process` (queries OK), registry reads via
     `Get-ItemProperty 'HKLM:\...' / 'HKCU:\...'` (reads OK).
4. **Delete is wrapped as a "safe delete".**
   - `Remove-Item -LiteralPath X -Recurse -Force` is intercepted and converted to a recycle-bin move.
   - Even on success it prints noise like `[safe-delete][SAFE_DELETE_FAIL_CLOSED]` +
     "无法找到指定文件" / "Some operations were aborted". **The only reliable success check is
     `Test-Path` == False afterwards**, plus checking the drive's `$RECYCLE.BIN`.
   - For dirs > ~1 GB or with thousands of files the wrapper genuinely fails
     ("Some operations were aborted") and is NOT bypassable — `dangerouslyDisableSandbox` has no effect and
     `[System.IO.Directory]::Delete` is blocked too. Then tell the user to delete from their own Explorer /
     terminal (no such limit there) and give exact paths.
5. **Recycle bin is per-drive.** `<drive>:\$RECYCLE.BIN` holds only that drive's deletions. Moving to the
   recycle bin does NOT free space — the bin must be emptied to reclaim it.
6. **Background PowerShell (run_in_background=true) mangles Chinese directory names** in written output.
   If names matter: obtain an ordered plain listing of the target dir (foreground, correct Chinese), pair
   with the (alphabetically ordered) background scan results by index, or measure specific dirs in the
   foreground.
7. Long whole-disk scans must run in the background with incremental writes (one `Add-Content` per dir) so
   partial results are readable mid-run; you will be notified on completion.

## Command patterns

Drive overview:
```powershell
$vol = Get-Volume -DriveLetter C
# record SizeGB/FreeGB/UsedPct from $vol.Size / $vol.SizeRemaining
```

Targeted size helper (reuse in every PS session):
```powershell
function SzMB([string]$p){ if(Test-Path $p){ [math]::Round((Get-ChildItem $p -Recurse -Force -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum/1MB,1) } else { -1 } }
```

Recursive sizing: `scripts/measure_dirs.ps1` (parameterized, pure ASCII; can be inlined). Notes:
- enumerate with `[System.IO.Directory]::EnumerateFiles/EnumerateDirectories` + `FileInfo.Length`
  (much faster than `Get-ChildItem -Recurse`)
- per-file try/catch to skip permission/usage errors
- pass `-OutFile` pointing into the workspace

Process locks:
```powershell
Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -like '<prefix>*' }
```

Registry install locations:
```powershell
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object DisplayName
# then compare DisplayName/InstallLocation against candidate folders
```

System restore/shadow storage needs admin (`Get-CimInstance Win32_ShadowStorage` usually unreadable) —
just mark it "需管理员".
