[CmdletBinding()]
param(
    [string]$Device = "windows",
    [string]$ApiBaseUrl = "",
    [switch]$NoMobile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDirectory = Join-Path $projectRoot ".run"
$backendDirectory = Join-Path $projectRoot "backend"
$mobileDirectory = Join-Path $projectRoot "mobile"
$composeFile = Join-Path $projectRoot "docker-compose.yml"
$stateFile = Join-Path $runDirectory "backend-state.json"
$dbOwnedFile = Join-Path $runDirectory "db-owned"
$backendLog = Join-Path $runDirectory "backend.log"
$backendErrorLog = Join-Path $runDirectory "backend-error.log"

function Import-DotEnv {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#")) { continue }
        $parts = $trimmed.Split("=", 2)
        if ($parts.Count -ne 2 -or $parts[0].Trim() -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw "Invalid .env line: $line"
        }
        $value = $parts[1].Trim().Trim('"').Trim("'")
        [Environment]::SetEnvironmentVariable($parts[0].Trim(), $value, "Process")
    }
}

function Assert-Command {
    param([string]$Name, [string]$InstallHint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required. $InstallHint"
    }
}

function Invoke-NativeQuietly {
    param([scriptblock]$Command)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $Command *> $null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Test-TcpPort {
    param([string]$HostName, [int]$Port)
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        return $task.Wait(500) -and $client.Connected
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Get-OwnedBackendProcess {
    if (-not (Test-Path -LiteralPath $stateFile)) { return $null }
    try {
        $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        if ($state.kind -ne "field-notes-backend" -or [int]$state.pid -le 0) { return $null }
        $expectedJarRoot = [IO.Path]::GetFullPath((Join-Path $backendDirectory "target")) + [IO.Path]::DirectorySeparatorChar
        $stateJarPath = [IO.Path]::GetFullPath([string]$state.jarPath)
        if (-not $stateJarPath.StartsWith($expectedJarRoot, [StringComparison]::OrdinalIgnoreCase)) { return $null }
        $process = Get-Process -Id ([int]$state.pid) -ErrorAction SilentlyContinue
        if (-not $process) { return $null }
        if ($process.StartTime.ToUniversalTime().ToString("O") -ne [string]$state.startedAtUtc) { return $null }
        $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)" -ErrorAction SilentlyContinue
        if (-not $processInfo -or $processInfo.CommandLine.IndexOf($stateJarPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $null }
        return $process
    } catch {
        return $null
    }
}

function Get-BackendFailureDetails {
    $sections = @()
    if (Test-Path -LiteralPath $backendLog) {
        $sections += "--- backend.log ---`n$((Get-Content -LiteralPath $backendLog -Tail 30) -join "`n")"
    }
    if (Test-Path -LiteralPath $backendErrorLog) {
        $sections += "--- backend-error.log ---`n$((Get-Content -LiteralPath $backendErrorLog -Tail 30) -join "`n")"
    }
    if ($sections.Count -eq 0) { return "No backend logs were produced." }
    return $sections -join "`n"
}

function Wait-ForDatabase {
    param([int]$TimeoutSeconds = 60)
    $dbUser = if ($env:DB_USER) { $env:DB_USER } else { "fieldnotes" }
    $dbName = if ($env:DB_NAME) { $env:DB_NAME } else { "fieldnotes" }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $exitCode = Invoke-NativeQuietly {
            docker compose -f $composeFile exec -T db pg_isready -U $dbUser -d $dbName
        }
        if ($exitCode -eq 0) { return }
        Start-Sleep -Seconds 1
    }

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & docker compose -f $composeFile logs --tail 30 db
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    throw "PostgreSQL did not become ready within $TimeoutSeconds seconds."
}

function Wait-ForBackend {
    param([System.Diagnostics.Process]$Process, [int]$Port, [int]$TimeoutSeconds = 90)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ($Process.HasExited) {
            throw "The backend stopped before it became ready.`n$(Get-BackendFailureDetails)"
        }
        $applicationStarted = (Test-Path -LiteralPath $backendLog) -and
            (Select-String -LiteralPath $backendLog -SimpleMatch "Started FieldNotesApplication" -Quiet)
        if ($applicationStarted -and (Test-TcpPort -HostName "localhost" -Port $Port)) { return }
        Start-Sleep -Seconds 1
    }
    throw "The backend did not open port $Port within $TimeoutSeconds seconds.`n$(Get-BackendFailureDetails)"
}

Import-DotEnv -Path (Join-Path $projectRoot ".env")
Assert-Command "docker" "Install Docker Desktop and start it."
Assert-Command "java" "Install Java 17 or newer."
if (-not $NoMobile) { Assert-Command "flutter" "Install Flutter 3.27 or newer." }

$javaVersion = (& cmd.exe /d /c "java -version 2>&1" | Out-String)
if ($LASTEXITCODE -ne 0 -or $javaVersion -notmatch 'version "(\d+)') {
    throw "Could not determine the installed Java version."
}
if ([int]$Matches[1] -lt 17) { throw "Java 17 or newer is required. Found Java $($Matches[1])." }

if ((Invoke-NativeQuietly { docker info }) -ne 0) {
    throw "Docker is installed but the Docker engine is not running."
}

New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
$previousPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $runningServices = @(& docker compose -f $composeFile ps --status running --services 2>$null)
    $composeStatusExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousPreference
}
if ($composeStatusExitCode -ne 0) { throw "Docker Compose could not inspect the project services." }
$dbWasRunning = $runningServices -contains "db"

Write-Host "Starting PostgreSQL..." -ForegroundColor Cyan
& docker compose -f $composeFile up -d db
if ($LASTEXITCODE -ne 0) { throw "Docker Compose could not start PostgreSQL." }
$dbContainerId = [string](& docker compose -f $composeFile ps -q db 2>$null | Select-Object -First 1)
$dbContainerId = $dbContainerId.Trim()
if (-not $dbContainerId) { throw "Docker Compose started PostgreSQL but did not return its container ID." }
if (-not $dbWasRunning) {
    Set-Content -LiteralPath $dbOwnedFile -Value $dbContainerId
} elseif (Test-Path -LiteralPath $dbOwnedFile) {
    $recordedDbId = (Get-Content -LiteralPath $dbOwnedFile -Raw).Trim()
    if ($recordedDbId -ne $dbContainerId) {
        Remove-Item -LiteralPath $dbOwnedFile -Force
        Write-Warning "Removed stale database ownership state; the running database will not be stopped by stop.ps1."
    }
}
Wait-ForDatabase

$backendPort = if ($env:PORT) { [int]$env:PORT } else { 8080 }
$backendProcess = Get-OwnedBackendProcess
if ($backendProcess) {
    $ownedState = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    if ([int]$ownedState.port -ne $backendPort) {
        throw "The owned backend is running on port $($ownedState.port), but PORT is now $backendPort. Run .\stop.ps1, then start again."
    }
    if (-not (Test-TcpPort "localhost" $backendPort)) {
        Wait-ForBackend -Process $backendProcess -Port $backendPort
    }
    Write-Host "Backend is already running (PID $($backendProcess.Id))." -ForegroundColor DarkGray
} else {
    Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
    if (Test-TcpPort "localhost" $backendPort) {
        throw "Port $backendPort is already used by a process not started by this launcher. Stop it or set PORT in .env."
    }

    Remove-Item -LiteralPath $backendLog, $backendErrorLog -Force -ErrorAction SilentlyContinue
    Write-Host "Building Spring Boot API..." -ForegroundColor Cyan
    Push-Location $backendDirectory
    try {
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & .\mvnw.cmd -q -DskipTests package
            $buildExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousPreference
        }
        if ($buildExitCode -ne 0) { throw "The backend build failed." }
    } finally {
        Pop-Location
    }

    $jar = Get-ChildItem -LiteralPath (Join-Path $backendDirectory "target") -Filter "*.jar" |
        Where-Object { $_.Name -notlike "*.original" } | Select-Object -First 1
    if (-not $jar) { throw "The backend build completed but no executable JAR was found." }

    Write-Host "Starting Spring Boot API..." -ForegroundColor Cyan
    $backendProcess = Start-Process -FilePath "java.exe" `
        -ArgumentList "-jar", "`"$($jar.FullName)`"" `
        -WorkingDirectory $backendDirectory `
        -RedirectStandardOutput $backendLog `
        -RedirectStandardError $backendErrorLog `
        -WindowStyle Hidden `
        -PassThru
    $state = [ordered]@{
        kind = "field-notes-backend"
        pid = $backendProcess.Id
        startedAtUtc = $backendProcess.StartTime.ToUniversalTime().ToString("O")
        jarPath = $jar.FullName
        port = $backendPort
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $stateFile
    Wait-ForBackend -Process $backendProcess -Port $backendPort
}

Write-Host "API ready at http://localhost:$backendPort" -ForegroundColor Green
if ($NoMobile) {
    Write-Host "Backend-only startup complete. Run .\stop.ps1 when finished."
    exit 0
}

Write-Host "Restoring Flutter packages..." -ForegroundColor Cyan
Push-Location $mobileDirectory
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

    if (-not $ApiBaseUrl) { $ApiBaseUrl = $env:API_BASE_URL }
    if (-not $ApiBaseUrl) {
        $devices = @((& flutter devices --machine | Out-String) | ConvertFrom-Json)
        $selectedDevice = $devices | Where-Object {
            $_.id -eq $Device -or $_.name -eq $Device
        } | Select-Object -First 1
        if (-not $selectedDevice) {
            $selectedDevice = $devices | Where-Object {
                $_.id.StartsWith($Device, [System.StringComparison]::OrdinalIgnoreCase) -or
                $_.name.StartsWith($Device, [System.StringComparison]::OrdinalIgnoreCase)
            } | Select-Object -First 1
        }
        if (-not $selectedDevice) {
            throw "Could not identify device '$Device'. Pass -ApiBaseUrl explicitly or use a listed Flutter device id."
        }
        if ($selectedDevice.targetPlatform -like "android*") {
            if (-not $selectedDevice.emulator) {
                throw "A physical Android device needs a host-reachable URL. Re-run with -ApiBaseUrl http://<your-computer-ip>:$backendPort."
            }
            $ApiBaseUrl = "http://10.0.2.2:$backendPort"
        } else {
            $ApiBaseUrl = "http://localhost:$backendPort"
        }
    }

    Write-Host "Launching Flutter on '$Device' with API $ApiBaseUrl..." -ForegroundColor Cyan
    & flutter run -d $Device "--dart-define=API_BASE_URL=$ApiBaseUrl"
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
