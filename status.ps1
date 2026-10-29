<#
.SYNOPSIS
    Show status of all C2inaBox services.
#>
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Push-Location $ScriptDir

Write-Host ""
Write-Host "  C2inaBox Status" -ForegroundColor Cyan
Write-Host "  ═══════════════" -ForegroundColor Cyan
Write-Host ""

docker compose --profile run ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>$null

Write-Host ""

# Quick health checks
try {
    $es = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "  Elasticsearch : $($es.status)" -ForegroundColor $(if ($es.status -eq "green") {"Green"} elseif ($es.status -eq "yellow") {"Yellow"} else {"Red"})
} catch {
    Write-Host "  Elasticsearch : DOWN" -ForegroundColor Red
}

try {
    $kb = Invoke-WebRequest -Uri "http://localhost:5601/api/status" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "  Kibana        : UP" -ForegroundColor Green
} catch {
    Write-Host "  Kibana        : DOWN or starting" -ForegroundColor Yellow
}

try {
    # Adaptix uses WSS on 4321 — just check the port is listening
    $tcp = Test-NetConnection -ComputerName localhost -Port 4321 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($tcp) {
        Write-Host "  Adaptix C2    : UP (port 4321)" -ForegroundColor Green
    } else {
        Write-Host "  Adaptix C2    : DOWN" -ForegroundColor Red
    }
} catch {
    Write-Host "  Adaptix C2    : UNKNOWN" -ForegroundColor Yellow
}

Write-Host ""
Pop-Location
