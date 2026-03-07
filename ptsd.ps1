# ptsd - Project Terminal Switch Directory (PowerShell)
# Lists recent Claude project directories and navigates to the selected one.
#
# Installation: add the following to your PowerShell profile ($PROFILE):
#   . "C:\path\to\ptsd\ptsd.ps1"
#
# Then run: ptsd

function ptsd {
    $projectsDir = "$env:USERPROFILE\.claude\projects"

    if (-not (Test-Path $projectsDir)) {
        Write-Host "No Claude projects directory found at $projectsDir"
        return
    }

    $cwds = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Get project dirs sorted by most recently modified (newest first)
    $projectDirs = Get-ChildItem -Path $projectsDir -Directory |
                   Sort-Object LastWriteTime -Descending

    foreach ($projectDir in $projectDirs) {
        # Find the newest JSONL file in this project dir
        $newestJsonl = Get-ChildItem -Path $projectDir.FullName -Filter '*.jsonl' -ErrorAction SilentlyContinue |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -First 1

        if (-not $newestJsonl) { continue }

        # Find the first line containing a cwd field and parse it
        $cwd = $null
        foreach ($line in [System.IO.File]::ReadLines($newestJsonl.FullName)) {
            if ($line -notmatch '"cwd"') { continue }
            try {
                $cwd = ($line | ConvertFrom-Json).cwd
                break
            } catch { continue }
        }

        if (-not $cwd) { continue }
        if (-not (Test-Path $cwd)) { continue }
        if (-not $seen.Add($cwd)) { continue }  # Add returns false if already present

        $cwds.Add($cwd)
    }

    if ($cwds.Count -eq 0) {
        Write-Host 'No Claude project directories found.'
        return
    }

    Write-Host ''
    for ($i = 0; $i -lt $cwds.Count; $i++) {
        Write-Host ('  {0,2}) {1}' -f ($i + 1), $cwds[$i])
    }
    Write-Host ''

    $selection = Read-Host "Select project (1-$($cwds.Count))"

    if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $cwds.Count) {
        $target = $cwds[[int]$selection - 1]
        Write-Host "→ $target"
        Set-Location $target
    } else {
        Write-Host 'Invalid selection'
    }
}
