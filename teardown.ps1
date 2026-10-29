<#
.SYNOPSIS
    Tear down C2inaBox stack.
.PARAMETER Purge
    Also remove Docker volumes (Elastic data, Adaptix build artifacts and data).
    Without this flag, data is preserved for next deploy.
#>
[CmdletBinding()]
param(
    [switch]$Purge
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Push-Location $ScriptDir

Write-Host "[*] Stopping C2inaBox services..." -ForegroundColor Yellow
docker compose --profile run down
docker compose --profile build down 2>$null

if ($Purge) {
    Write-Host "[*] Removing volumes (Elastic data, Adaptix artifacts)..." -ForegroundColor Yellow
    docker volume rm c2inabox_adaptix-dist c2inabox_adaptix-data c2inabox_es-data 2>$null
    Write-Host "[+] Volumes purged. Next deploy will rebuild from scratch." -ForegroundColor Green
} else {
    Write-Host "[+] Services stopped. Data volumes preserved — next deploy will be fast." -ForegroundColor Green
    Write-Host "    Use -Purge to also remove data volumes." -ForegroundColor DarkGray
}

Pop-Location
