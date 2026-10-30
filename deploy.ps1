<#
.SYNOPSIS
    Deploy C2inaBox — Adaptix C2 + Elastic + Kibana in Docker.
.DESCRIPTION
    Builds the Adaptix C2 server from source (first run only), then starts
    the full stack: Adaptix teamserver, Elasticsearch, and Kibana.
    Automatically creates the default HTTPS listener on port 8443.
.PARAMETER SkipBuild
    Skip the Adaptix build step (use cached build artifacts).
.PARAMETER ElasticOnly
    Start only Elasticsearch + Kibana, no Adaptix.
.PARAMETER Force
    Force rebuild Adaptix even if artifacts exist.
.PARAMETER NoListener
    Skip automatic HTTPS listener creation.
.PARAMETER GeneratePayload
    Generate a default x64 beacon EXE after creating the listener.
.PARAMETER PayloadDir
    Directory for generated payloads. Defaults to C:\Tools\Payloads.
.PARAMETER EnrollAgent
    Download and enroll Elastic Agent on this host after stack is up.
.PARAMETER SkipEnroll
    Skip Elastic Agent enrollment even if not already enrolled.
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$ElasticOnly,
    [switch]$Force,
    [switch]$NoListener,
    [switch]$GeneratePayload,
    [string]$PayloadDir = "C:\Tools\Payloads",
    [switch]$EnrollAgent,
    [switch]$SkipEnroll
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Push-Location $ScriptDir

function Write-Banner {
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │         C 2 i n a B o x         │" -ForegroundColor Cyan
    Write-Host "  │  Adaptix C2 + Elastic + Kibana  │" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Docker {
    try {
        docker info *> $null
        return $true
    } catch {
        return $false
    }
}

Write-Banner

# Preflight
if (-not (Test-Docker)) {
    Write-Host "[!] Docker is not running. Start Docker Desktop and try again." -ForegroundColor Red
    Pop-Location; exit 1
}

# Build Adaptix if needed
if (-not $ElasticOnly -and -not $SkipBuild) {
    $needsBuild = $Force
    if (-not $needsBuild) {
        $volCheck = docker volume ls --format "{{.Name}}" 2>$null | Select-String "c2inabox_adaptix-dist"
        if (-not $volCheck) { $needsBuild = $true }
    }

    if ($needsBuild) {
        Write-Host "[*] Building Adaptix C2 server + extenders (this takes a few minutes on first run)..." -ForegroundColor Yellow
        docker compose --profile build up --build
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Adaptix build failed." -ForegroundColor Red
            Pop-Location; exit 1
        }
        Write-Host "[+] Adaptix build complete." -ForegroundColor Green
    } else {
        Write-Host "[*] Adaptix build artifacts found, skipping build. Use -Force to rebuild." -ForegroundColor DarkGray
    }
}

# Start the stack
if ($ElasticOnly) {
    Write-Host "[*] Starting Elasticsearch + Kibana..." -ForegroundColor Yellow
    docker compose --profile run up -d elasticsearch kibana
} else {
    Write-Host "[*] Starting full stack (Adaptix + Elastic + Kibana)..." -ForegroundColor Yellow
    docker compose --profile run up -d
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Failed to start services." -ForegroundColor Red
    Pop-Location; exit 1
}

# Wait for health
Write-Host "[*] Waiting for services to become healthy..." -ForegroundColor Yellow
$timeout = 120
$elapsed = 0
while ($elapsed -lt $timeout) {
    try {
        $health = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health" -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($health.status -in @("green", "yellow")) { break }
    } catch {}
    Start-Sleep -Seconds 3
    $elapsed += 3
}

# Wait for Adaptix to accept connections
if (-not $ElasticOnly) {
    Write-Host "[*] Waiting for Adaptix teamserver..." -ForegroundColor Yellow
    $adaptixReady = $false
    $adaptixTimeout = 60
    $adaptixElapsed = 0
    while ($adaptixElapsed -lt $adaptixTimeout) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.Connect("127.0.0.1", 4321)
            $tcp.Close()
            $adaptixReady = $true
            break
        } catch {}
        Start-Sleep -Seconds 2
        $adaptixElapsed += 2
    }
    if (-not $adaptixReady) {
        Write-Host "[!] Adaptix did not become reachable within $adaptixTimeout seconds." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[+] C2inaBox is running:" -ForegroundColor Green
$esPort = if ($env:ES_PORT) { $env:ES_PORT } else { '9200' }
$kbPort = if ($env:KIBANA_PORT) { $env:KIBANA_PORT } else { '5601' }
Write-Host "    Elasticsearch : http://localhost:$esPort" -ForegroundColor White
Write-Host "    Kibana        : http://localhost:$kbPort" -ForegroundColor White
if (-not $ElasticOnly) {
    Write-Host "    Adaptix C2    : https://localhost:4321/endpoint" -ForegroundColor White
    Write-Host "    Listener      : https://localhost:8443" -ForegroundColor White
    Write-Host "    Credentials   : (see config/profile.yaml)" -ForegroundColor DarkGray
}
Write-Host ""

# Auto-create HTTPS listener
if (-not $ElasticOnly -and -not $NoListener -and $adaptixReady) {
    $listenerArgs = @{}
    if ($GeneratePayload) { $listenerArgs["GeneratePayload"] = $true }
    if ($PayloadDir) { $listenerArgs["PayloadDir"] = $PayloadDir }
    & "$ScriptDir\setup-listener.ps1" @listenerArgs
}

# Auto-enroll Elastic Agent
if (-not $SkipEnroll) {
    $agentSvc = Get-Service -Name "Elastic Agent" -ErrorAction SilentlyContinue
    if ($agentSvc) {
        Write-Host "[*] Elastic Agent already installed (status: $($agentSvc.Status))" -ForegroundColor DarkGray
    } elseif ($EnrollAgent -or (-not $ElasticOnly)) {
        Write-Host ""
        Write-Host "[*] Enrolling Elastic Agent on this host..." -ForegroundColor Yellow
        Write-Host "    Waiting for Fleet Server and SIEM setup to finish..." -ForegroundColor DarkGray

        $fleetReady = $false
        for ($i = 1; $i -le 30; $i++) {
            try {
                $fleetHealth = Invoke-RestMethod -Uri "http://localhost:8220/api/status" `
                    -TimeoutSec 3 -ErrorAction Stop -UseBasicParsing
                $fleetReady = $true
                break
            } catch {}
            Start-Sleep -Seconds 5
        }

        if ($fleetReady) {
            & "$ScriptDir\enroll-agent.ps1"
        } else {
            Write-Host "[!] Fleet Server not reachable after 150s. Run enroll-agent.ps1 manually." -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "[*] Use .\teardown.ps1 to stop everything." -ForegroundColor DarkGray

Pop-Location
