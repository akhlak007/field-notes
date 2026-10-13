# Writes gitignored .render.env with JDBC values for the Render dashboard.
# Does not print secrets.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outFile = Join-Path $root ".render.env"
$tmpFile = Join-Path $root ".neon-url.tmp"

try {
    neon connection-string production `
        --project-id spring-lake-01394771 `
        --database-name neondb `
        --role-name neondb_owner `
        --ssl require |
        Out-File -FilePath $tmpFile -Encoding ascii -NoNewline

    $raw = (Get-Content -LiteralPath $tmpFile -Raw).Trim()
    if (-not $raw) { throw "neon connection-string returned nothing" }

    $uri = [System.Uri]$raw
    $userInfo = $uri.UserInfo.Split(":", 2)
    if ($userInfo.Count -ne 2) { throw "Connection string is missing the role password" }

    $user = [Uri]::UnescapeDataString($userInfo[0])
    $password = [Uri]::UnescapeDataString($userInfo[1])
    $jdbc = "jdbc:postgresql://$($uri.Host)$($uri.AbsolutePath)?sslmode=require"

    @(
        "DB_URL=$jdbc"
        "DB_USER=$user"
        "DB_PASSWORD=$password"
        "SPRING_PROFILES_ACTIVE=prod"
        "SERVER_ADDRESS=0.0.0.0"
        "PHOTO_DIR=/app/uploads"
    ) | Set-Content -LiteralPath $outFile -Encoding utf8

    Write-Host "Wrote $outFile"
    Write-Host "Paste DB_URL, DB_USER, and DB_PASSWORD into Render → field-notes-api → Environment."
}
finally {
    if (Test-Path -LiteralPath $tmpFile) {
        Remove-Item -LiteralPath $tmpFile -Force
    }
}
