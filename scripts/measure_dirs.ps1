# measure_dirs.ps1
# Purpose: Recursively measure size/statistics of each top-level directory under Root.
# Works in any Windows host (WorkBuddy / Claude Code / other agents / local terminal).
# No machine-specific paths are hardcoded: everything comes from parameters.
#   - Keep this file pure ASCII to avoid mojibake in some hosts' background tasks.
#   - Writes results incrementally to OutFile (read partial results anytime).
#   - Run via a PowerShell tool, or `powershell -NoProfile -File ...` from Bash / CMD.
#     For large roots (C:\ / D:\) use background execution when the host supports it.
#
# Usage (paths below are placeholders - pass real values as parameters):
#   powershell -NoProfile -ExecutionPolicy Bypass -File measure_dirs.ps1 -Root "D:\" -OutFile "<输出目录>\scan.txt" -Exclude '$RECYCLE.BIN','System Volume Information'
#
# Output format per dir (pipe delimited, mostly ASCII; Chinese dir names may mojibake in background runs):
#   === <DirName>
#   TOTAL_GB=<n> | FILES=<n> | HIDDEN_MB=<n>(<n> files) | SYSTEM_FILES=<n> | CACHE_MB=<n>
#   EXT=<ext1>=<MB>;...   (top 12 by size)
#   BIG=<MB>|<path>;...   (top files)
# Also writes .lnk paths and duplicate candidates (name|size >= 20MB) if switches set.

param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$OutFile,
    [string[]]$Exclude = @('$RECYCLE.BIN', 'System Volume Information'),
    [switch]$TrackLnk,
    [switch]$TrackDup,
    [int]$BigCount = 20,
    [double]$DupMinMB = 20.0
)

$ErrorActionPreference = 'SilentlyContinue'
$outLines = New-Object System.Collections.ArrayList
[void]$outLines.Add('== DIR SCAN ==')
Set-Content -LiteralPath $OutFile -Value $outLines -Encoding UTF8

$script:dupeMap = @{}
$script:lnkList = New-Object System.Collections.ArrayList

function Get-TreeSize {
    param([string]$Path, [bool]$InCache)
    $isCache = $InCache -or ($Path -match '\\(temp|tmp|cache|crashdumps|logs?|node_modules|_npx|\.gradle|\.m2|\.cache|recycle|trash)(\\|$)')
    try {
        foreach ($f in [System.IO.Directory]::EnumerateFiles($Path)) {
            try {
                $fi = New-Object System.IO.FileInfo($f)
                $len = $fi.Length
                $script:t += $len
                $script:c++
                if ($isCache) { $script:cacheT += $len }
                $e = $fi.Extension.ToLower(); if (-not $e) { $e = '(none)' }
                if ($script:ext.ContainsKey($e)) { $script:ext[$e] += $len } else { $script:ext[$e] = $len }
                if ($fi.Attributes -band [System.IO.FileAttributes]::Hidden) { $script:hT += $len; $script:hC++ }
                if ($fi.Attributes -band [System.IO.FileAttributes]::System) { $script:sC++ }
                if ($TrackDup -and ($len -ge ($DupMinMB * 1MB))) {
                    $key = $fi.Name.ToLower() + '|' + $len
                    if ($script:dupeMap.ContainsKey($key)) { [void]$script:dupeMap[$key].Add($f) }
                    else { $script:dupeMap[$key] = New-Object System.Collections.ArrayList; [void]$script:dupeMap[$key].Add($f) }
                }
                if ($TrackLnk -and $e -eq '.lnk') { [void]$script:lnkList.Add($f) }
                if ($script:big.Count -lt $BigCount) {
                    [void]$script:big.Add([pscustomobject]@{ P = $f; L = $len })
                }
                else {
                    $minIdx = 0
                    for ($i = 1; $i -lt $script:big.Count; $i++) { if ($script:big[$i].L -lt $script:big[$minIdx].L) { $minIdx = $i } }
                    if ($len -gt $script:big[$minIdx].L) { $script:big[$minIdx] = [pscustomobject]@{ P = $f; L = $len } }
                }
            }
            catch { }
        }
        foreach ($d in [System.IO.Directory]::EnumerateDirectories($Path)) {
            Get-TreeSize $d $isCache
        }
    }
    catch { }
}

$roots = Get-ChildItem -LiteralPath $Root -Force -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin $Exclude }

foreach ($r in $roots) {
    $script:t = [long]0; $script:c = 0; $script:cacheT = [long]0
    $script:hT = [long]0; $script:hC = 0; $script:sC = 0
    $script:ext = @{}
    $script:big = New-Object System.Collections.ArrayList
    Get-TreeSize -Path $r.FullName -InCache $false

    $line1 = '=== ' + $r.Name
    $line2 = 'TOTAL_GB=' + [math]::Round($script:t / 1GB, 2) + ' | FILES=' + $script:c +
             ' | HIDDEN_MB=' + [math]::Round($script:hT / 1MB, 1) + '(' + $script:hC + ') | SYSTEM_FILES=' + $script:sC +
             ' | CACHE_MB=' + [math]::Round($script:cacheT / 1MB, 1)
    $exts = ($script:ext.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 12 |
             ForEach-Object { $_.Key + '=' + [math]::Round($_.Value / 1MB, 1) + 'MB' }) -join ';'
    $bign = ($script:big | Sort-Object L -Descending |
             ForEach-Object { [math]::Round($_.L / 1MB, 1).ToString() + 'MB|' + $_.P }) -join ' ; '
    Add-Content -LiteralPath $OutFile -Value ($line1, $line2, ('EXT=' + $exts), ('BIG=' + $bign)) -Encoding UTF8
    Write-Host ('DONE: ' + $r.Name)
}

if ($TrackLnk) {
    foreach ($l in $script:lnkList) { Add-Content -LiteralPath $OutFile -Value ('LNK=' + $l) -Encoding UTF8 }
}
if ($TrackDup) {
    foreach ($k in $script:dupeMap.Keys) {
        if ($script:dupeMap[$k].Count -gt 1) {
            foreach ($p in $script:dupeMap[$k]) { Add-Content -LiteralPath $OutFile -Value ('DUP=' + $k + '|' + $p) -Encoding UTF8 }
        }
    }
}
Add-Content -LiteralPath $OutFile -Value '== DONE ==' -Encoding UTF8
