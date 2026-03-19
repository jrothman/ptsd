# ptsd - Project Terminal Switch Directory (PowerShell)
# Lists recent Claude project directories and navigates to the selected one.
#
# Installation: add the following to your PowerShell profile ($PROFILE):
#   . "C:\path\to\ptsd\ptsd.ps1"
#
# Then run: ptsd

function ptsd {
    param(
        [switch]$a,          # Sort alphabetically
        [switch]$o,          # Sort oldest first
        [switch]$n,          # Create new project
        [switch]$h,          # Show help
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Remaining
    )

    # Show help
    if ($h) {
        Write-Host "Usage: ptsd [-a|-o] [-n [name]] [filter]"
        Write-Host "  -a          Sort alphabetically by project name"
        Write-Host "  -o          Sort oldest first (default: newest first)"
        Write-Host "  -n [name]   Create a new project folder"
        Write-Host "  filter      Case-insensitive substring match on path"
        return
    }

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

    # Parse remaining args: first non-flag arg that isn't consumed by -n is the filter
    $filter = ""
    $newProject = ""
    if ($n -and $Remaining.Count -gt 0) {
        $newProject = $Remaining[0]
        if ($Remaining.Count -gt 1) {
            $filter = $Remaining[1]
        }
    } elseif ($Remaining.Count -gt 0) {
        $filter = $Remaining[0]
    }

    # Handle new project creation
    if ($n) {
        # Collect unique base paths (parent dirs) from existing projects
        $basePaths = [System.Collections.Generic.List[string]]::new()
        $baseSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($cwd in $cwds) {
            $parent = Split-Path $cwd -Parent
            if ($baseSeen.Add($parent)) {
                $basePaths.Add($parent)
            }
        }

        if ($basePaths.Count -eq 0) {
            Write-Host "No base paths found from existing projects."
            return
        }

        # Let user choose base path
        $chosenBase = ""
        if ($basePaths.Count -eq 1) {
            $chosenBase = $basePaths[0]
            Write-Host "Base path: $chosenBase"
        } else {
            Write-Host ""
            Write-Host "Choose a base path:"
            for ($bi = 0; $bi -lt $basePaths.Count; $bi++) {
                $displayBp = $basePaths[$bi] -replace [regex]::Escape($env:USERPROFILE), '~'
                Write-Host ('  {0,2}) {1}' -f ($bi + 1), $displayBp)
            }
            Write-Host ""
            $bpSelection = Read-Host "Select base path (1-$($basePaths.Count))"
            if ($bpSelection -match '^\d+$' -and [int]$bpSelection -ge 1 -and [int]$bpSelection -le $basePaths.Count) {
                $chosenBase = $basePaths[[int]$bpSelection - 1]
            } else {
                Write-Host "Invalid selection."
                return
            }
        }

        # Get project name if not provided
        if (-not $newProject) {
            $newProject = Read-Host "Project name"
            if (-not $newProject) {
                Write-Host "No project name provided."
                return
            }
        }

        $newDir = Join-Path $chosenBase $newProject

        # Check if it already exists
        if (Test-Path $newDir) {
            Write-Host "`"$newDir`" already exists."
            $switchTo = Read-Host "Switch to it? (Y/n)"
            if ($switchTo -eq 'n' -or $switchTo -eq 'N') {
                return
            }
            Set-Location $newDir
        } else {
            New-Item -ItemType Directory -Path $newDir -Force | Out-Null
            Write-Host "Created: $newDir"
            Set-Location $newDir
        }
        $launch = Read-Host "Launch Claude here? (Y/n)"
        if ($launch -ne 'n' -and $launch -ne 'N') {
            claude
        }
        return
    }

    # Apply sort
    if ($a) {
        # Sort alphabetically by project name (basename), case-insensitive
        $cwds = [System.Collections.Generic.List[string]]::new(
            ($cwds | Sort-Object { (Split-Path $_ -Leaf).ToLower() })
        )
    } elseif ($o) {
        # Reverse the array (it's already newest-first)
        $reversed = [System.Collections.Generic.List[string]]::new($cwds)
        $reversed.Reverse()
        $cwds = $reversed
    }

    # Apply filter if provided
    if ($filter) {
        $filtered = [System.Collections.Generic.List[string]]::new()
        foreach ($cwd in $cwds) {
            if ($cwd -like "*$filter*") {
                $filtered.Add($cwd)
            }
        }
        $cwds = $filtered
        if ($cwds.Count -eq 0) {
            Write-Host "No projects matching `"$filter`"."
            return
        }
    }

    # Display numbered list: project name bold, path dim on same line
    Write-Host ''
    Write-Host ('   0) ') -NoNewline
    Write-Host 'help menu' -ForegroundColor Cyan
    for ($i = 0; $i -lt $cwds.Count; $i++) {
        $name = Split-Path $cwds[$i] -Leaf
        $displayPath = $cwds[$i] -replace [regex]::Escape($env:USERPROFILE), '~'
        Write-Host ('  {0,2}) ' -f ($i + 1)) -NoNewline
        Write-Host $name -NoNewline -ForegroundColor White
        Write-Host "  $displayPath" -ForegroundColor DarkGray
    }
    Write-Host ''

    $selection = Read-Host "Select project (0-$($cwds.Count))"

    if ($selection -eq '0') {
        ptsd -h
        return
    } elseif ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $cwds.Count) {
        $target = $cwds[[int]$selection - 1]
        Write-Host "→ $target"
        Set-Location $target
        $launch = Read-Host "Launch Claude here? (Y/n)"
        if ($launch -ne 'n' -and $launch -ne 'N') {
            claude
        }
    } else {
        Write-Host 'Invalid selection'
    }
}
