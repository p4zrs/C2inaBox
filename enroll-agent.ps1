# enroll-agent.ps1 — Download and enroll Elastic Agent on this Windows host
# Run as Administrator after the C2inaBox stack is up with Fleet Server
#
# Usage: powershell -ExecutionPolicy Bypass -File enroll-agent.ps1

param(
    [string]$FleetUrl     = "http://localhost:8220",
    [string]$KibanaUrl    = "http://localhost:5601",
    [string]$EsUser       = "elastic",
    [string]$EsPassword   = "c2inabox-lab",
    [string]$InstallDir   = "C:\Program Files\Elastic\Agent"
)

$agentVersion = "8.15.3"
$agentZip     = "$env:TEMP\elastic-agent-$agentVersion-windows-x86_64.zip"
$agentDir     = "$env:TEMP\elastic-agent-$agentVersion-windows-x86_64"

# ── 1. Download agent ────────────────────────────────────
if (-not (Test-Path "$agentDir\elastic-agent.exe")) {
    Write-Host "[*] Downloading Elastic Agent $agentVersion..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-$agentVersion-windows-x86_64.zip" `
        -OutFile $agentZip -UseBasicParsing
    Write-Host "[*] Extracting..." -ForegroundColor Cyan
    Expand-Archive -Path $agentZip -DestinationPath $env:TEMP -Force
    Remove-Item $agentZip -ErrorAction SilentlyContinue
}
Write-Host "[+] Agent binary ready" -ForegroundColor Green

# ── 2. Get enrollment token from Fleet API ───────────────
Write-Host "[*] Fetching enrollment token from Kibana..." -ForegroundColor Cyan

$maxRetries = 12
$token = $null
for ($i = 1; $i -le $maxRetries; $i++) {
    try {
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${EsUser}:${EsPassword}"))
            "kbn-xsrf"      = "true"
        }
        $resp = Invoke-RestMethod -Uri "$KibanaUrl/api/fleet/enrollment_api_keys" `
            -Headers $headers -UseBasicParsing -ErrorAction Stop

        if ($resp.items -and $resp.items.Count -gt 0) {
            $token = $resp.items[0].api_key
            Write-Host "[+] Got enrollment token" -ForegroundColor Green
            break
        }
    } catch {
        Write-Host "  Waiting for Fleet API (attempt $i/$maxRetries)..." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 10
}

if (-not $token) {
    Write-Host "[!] Could not get enrollment token. Is Fleet Server running?" -ForegroundColor Red
    Write-Host "    Check: curl -u elastic:c2inabox-lab http://localhost:5601/api/fleet/enrollment_api_keys" -ForegroundColor Red
    exit 1
}

# ── 3. Install and enroll ────────────────────────────────
Write-Host "[*] Installing Elastic Agent..." -ForegroundColor Cyan
Write-Host "    Fleet URL: $FleetUrl" -ForegroundColor Gray
Write-Host "    Install dir: $InstallDir" -ForegroundColor Gray

& "$agentDir\elastic-agent.exe" install `
    --url="$FleetUrl" `
    --enrollment-token="$token" `
    --insecure `
    --non-interactive `
    --force

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== Elastic Agent Enrolled ===" -ForegroundColor Green
    Write-Host "  Agent is now reporting to Fleet Server at $FleetUrl"
    Write-Host "  Check Kibana > Fleet > Agents to see it online"
    Write-Host ""
    Write-Host "  Next steps:"
    Write-Host "    1. In Kibana, go to Fleet > Agent policies > Default policy"
    Write-Host "    2. Add 'Elastic Defend' integration (Endpoint Security)"
    Write-Host "    3. Set protection level to 'Detect' (not Prevent) for lab use"
    Write-Host "    4. Run the BOFs and check Security > Alerts"
} else {
    Write-Host "[!] Agent install failed (exit code $LASTEXITCODE)" -ForegroundColor Red
    Write-Host "    Try running manually from: $agentDir" -ForegroundColor Yellow
}
