<#
.SYNOPSIS
    Creates the default HTTPS listener on the Adaptix C2 teamserver.
.DESCRIPTION
    Logs into the teamserver, creates a BeaconHTTP listener on port 8443
    with HTTPS enabled, and optionally generates a beacon payload.
.PARAMETER PayloadDir
    Directory to save generated payloads. Defaults to C:\Tools\Payloads.
.PARAMETER GeneratePayload
    Generate a default x64 Exe beacon after creating the listener.
.PARAMETER ListenerPort
    Port for the HTTPS listener. Defaults to 8443.
.PARAMETER TeamserverPort
    Adaptix teamserver API port. Defaults to 4321.
#>
[CmdletBinding()]
param(
    [string]$PayloadDir = "C:\Tools\Payloads",
    [switch]$GeneratePayload,
    [int]$ListenerPort = 8443,
    [int]$TeamserverPort = 4321
)

$ErrorActionPreference = 'Stop'

# Load profile to get credentials
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$profilePath = Join-Path $ScriptDir "config\profile.yaml"
if (-not (Test-Path $profilePath)) {
    Write-Host "[!] config/profile.yaml not found. Copy from profile.example.yaml first." -ForegroundColor Red
    exit 1
}

$profileContent = Get-Content $profilePath -Raw

# Parse password and endpoint from YAML (simple regex, no module needed)
$password = if ($profileContent -match '(?m)^\s*password:\s*"?([^"\r\n]+)"?') { $Matches[1].Trim() } else { "pass" }
$endpoint = if ($profileContent -match '(?m)^\s*endpoint:\s*"?([^"\r\n]+)"?') { $Matches[1].Trim() } else { "/endpoint" }

# Parse first operator credentials
$opUser = ""; $opPass = ""
if ($profileContent -match '(?m)^\s*only_password:\s*true') {
    $opUser = "user"
    $opPass = $password
} else {
    if ($profileContent -match '(?m)^\s+(\w+):\s*"?([^"\r\n]+)"?\s*$') {
        $opUser = $Matches[1]; $opPass = $Matches[2].Trim()
    }
}

$baseUrl = "https://localhost:$TeamserverPort$endpoint"

# Disable cert validation for self-signed
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
} catch {}
# Also set TLS 1.2+
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Write-Host "[*] Logging into Adaptix at $baseUrl ..." -ForegroundColor Yellow

# Login
$loginBody = @{ username = $opUser; password = $opPass; version = "1.2" } | ConvertTo-Json -Compress
try {
    $loginResp = Invoke-RestMethod -Uri "$baseUrl/login" -Method POST -Body $loginBody -ContentType "application/json" -UseBasicParsing
} catch {
    Write-Host "[!] Login failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Check that Adaptix is running and config/profile.yaml has correct credentials." -ForegroundColor DarkGray
    exit 1
}

if (-not $loginResp.access_token) {
    Write-Host "[!] Login failed — no access token returned." -ForegroundColor Red
    exit 1
}

$token = $loginResp.access_token
Write-Host "[+] Logged in as $opUser" -ForegroundColor Green

# Check if listener already exists
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
try {
    $listeners = Invoke-RestMethod -Uri "$baseUrl/listener/list" -Method GET -Headers $headers -UseBasicParsing
    $existing = $listeners | Where-Object { $_.l_name -eq "https-default" }
    if ($existing) {
        Write-Host "[*] Listener 'https-default' already exists (port $($existing.l_bind_port), status: $($existing.l_status))" -ForegroundColor DarkGray
        $skipCreate = $true
    }
} catch {
    $skipCreate = $false
}

if (-not $skipCreate) {
    # Generate random encrypt key
    $encryptKey = -join ((0..15) | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })

    $listenerConfig = @{
        host_bind           = "0.0.0.0"
        port_bind           = $ListenerPort
        callback_addresses  = @("localhost:$ListenerPort")
        http_method         = "POST"
        uri                 = @("/api/v1/status", "/updates/check", "/content/sync")
        user_agent          = @("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        hb_header           = "X-Request-Id"
        encrypt_key         = $encryptKey
        ssl                 = $true
        ssl_cert            = ""
        ssl_key             = ""
        'x-forwarded-for'   = $false
        host_header         = @()
        request_headers     = ""
        server_headers      = ""
        'page-error'        = "<html><body><h1>404 Not Found</h1></body></html>"
        'page-payload'      = "<<<PAYLOAD_DATA>>>"
    } | ConvertTo-Json -Compress

    $createBody = @{
        name   = "https-default"
        type   = "BeaconHTTP"
        config = $listenerConfig
    } | ConvertTo-Json -Compress

    Write-Host "[*] Creating HTTPS listener on port $ListenerPort ..." -ForegroundColor Yellow
    try {
        $createResp = Invoke-RestMethod -Uri "$baseUrl/listener/create" -Method POST -Body $createBody -Headers $headers -UseBasicParsing
        if ($createResp.ok) {
            Write-Host "[+] Listener 'https-default' created — HTTPS on port $ListenerPort" -ForegroundColor Green
        } else {
            Write-Host "[!] Listener creation failed: $($createResp.message)" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "[!] Listener creation failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Generate payload if requested
if ($GeneratePayload) {
    if (-not (Test-Path $PayloadDir)) {
        New-Item -ItemType Directory -Force $PayloadDir | Out-Null
    }

    $agentConfig = @{
        arch                = "x64"
        format              = "Exe"
        sleep               = "4s"
        jitter              = 0
        is_killdate         = $false
        kill_date           = ""
        kill_time           = ""
        is_workingtime      = $false
        start_time          = ""
        end_time            = ""
        svcname             = ""
        is_sideloading      = $false
        sideloading_content = ""
        iat_hiding          = $false
        use_proxy           = $false
        proxy_type          = ""
        proxy_host          = ""
        proxy_port          = 0
        proxy_username      = ""
        proxy_password      = ""
        rotation_mode       = "sequential"
    } | ConvertTo-Json -Compress

    $genBody = @{
        agent         = "beacon"
        listener_name = @("https-default")
        config        = $agentConfig
    } | ConvertTo-Json -Compress

    Write-Host "[*] Generating x64 beacon payload ..." -ForegroundColor Yellow
    try {
        $genResp = Invoke-RestMethod -Uri "$baseUrl/agent/generate" -Method POST -Body $genBody -Headers $headers -UseBasicParsing
        if ($genResp.ok) {
            $parts = $genResp.message -split ":"
            $fileName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($parts[0]))
            $fileBytes = [System.Convert]::FromBase64String($parts[1])
            $outPath = Join-Path $PayloadDir $fileName
            [System.IO.File]::WriteAllBytes($outPath, $fileBytes)
            Write-Host "[+] Payload saved: $outPath ($($fileBytes.Length) bytes)" -ForegroundColor Green
        } else {
            Write-Host "[!] Agent generation failed: $($genResp.message)" -ForegroundColor Red
        }
    } catch {
        Write-Host "[!] Agent generation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "    You may need to add $PayloadDir to Windows Defender exclusions." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "[*] Listener ready. Connect with the Adaptix client:" -ForegroundColor Cyan
Write-Host "    URL:      https://localhost:$TeamserverPort$endpoint" -ForegroundColor White
Write-Host "    User:     $opUser" -ForegroundColor White
Write-Host "    Password: (from config/profile.yaml)" -ForegroundColor DarkGray
Write-Host ""
