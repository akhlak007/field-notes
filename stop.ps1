[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDirectory = Join-Path $projectRoot ".run"
$stateFile = Join-Path $runDirectory "backend-state.json"
$dbOwnedFile = Join-Path $runDirectory "db-owned"
$composeFile = Join-Path $projectRoot "docker-compose.yml"

if (Test-Path -LiteralPath $stateFile) {
    $state = $null
    $ownedProcess = $null
    try {
        $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        if ($state.kind -eq "field-notes-backend" -and [int]$state.pid -gt 0) {
            $expectedJarRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot "backend\target")) + [IO.Path]::DirectorySeparatorChar
            $stateJarPath = [IO.Path]::GetFullPath([string]$state.jarPath)
            if (-not $stateJarPath.StartsWith($expectedJarRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Backend state references an unexpected JAR path."
            }
            $candidate = Get-Process -Id ([int]$state.pid) -ErrorAction SilentlyContinue
            if ($candidate -and $candidate.StartTime.ToUniversalTime().ToString("O") -eq [string]$state.startedAtUtc) {
                $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($candidate.Id)" -ErrorAction SilentlyContinue
                if ($processInfo -and $processInfo.CommandLine.IndexOf($stateJarPath, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $ownedProcess = $candidate
                }
            }
        }
    } catch { $state = $null }

    if ($ownedProcess) {
        Write-Host "Stopping Field Notes backend (PID $($ownedProcess.Id))..." -ForegroundColor Cyan
        Stop-Process -Id $ownedProcess.Id
        try { Wait-Process -Id $ownedProcess.Id -Timeout 10 -ErrorAction Stop } catch {
            Stop-Process -Id $ownedProcess.Id -Force -ErrorAction SilentlyContinue
        }
    } elseif ($state) {
        Write-Warning "Backend state is stale or does not match its process. No process was stopped."
    } else {
        Write-Warning "Backend state is invalid. No process was stopped."
    }
    Remove-Item -LiteralPath $stateFile -Force
}

if (Test-Path -LiteralPath $dbOwnedFile) {
    $recordedDbId = (Get-Content -LiteralPath $dbOwnedFile -Raw).Trim()
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $currentDbId = [string](& docker compose -f $composeFile ps -q db 2>$null | Select-Object -First 1)
        $composeInspectExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($composeInspectExitCode -ne 0) {
        throw "Could not inspect PostgreSQL ownership because Docker Compose is unavailable. Ownership state was preserved; retry stop.ps1 when Docker is running."
    }
    $currentDbId = $currentDbId.Trim()
    if ($recordedDbId -match '^[a-f0-9]{12,64}$' -and $recordedDbId -eq $currentDbId) {
        Write-Host "Stopping launcher-owned PostgreSQL container..." -ForegroundColor Cyan
        & docker compose -f $composeFile down
        if ($LASTEXITCODE -ne 0) { throw "Docker Compose could not stop the services." }
        Write-Host "Stopped. The PostgreSQL volume and all database data were preserved." -ForegroundColor Green
    } else {
        Write-Warning "Database ownership state does not match the running container. PostgreSQL was not stopped."
    }
    Remove-Item -LiteralPath $dbOwnedFile -Force
} else {
    Write-Host "No launcher-owned PostgreSQL container to stop." -ForegroundColor DarkGray
}
