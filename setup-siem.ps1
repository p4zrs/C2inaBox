# setup-siem.ps1 — Install Sysmon + Winlogbeat for C2inaBox lab
# Run as Administrator
#
# Downloads:
#   - Sysmon (Sysinternals)
#   - SwiftOnSecurity sysmon config
#   - Winlogbeat 8.15.3 (matches ES version)
#
# Ships Sysmon + Security + PowerShell events to localhost:9200

$ErrorActionPreference = "Continue"

$toolsDir = "C:\Tools\siem"
$sysmonDir = "$toolsDir\sysmon"
$wbDir     = "$toolsDir\winlogbeat"

Write-Host "[*] Creating directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force $sysmonDir | Out-Null
New-Item -ItemType Directory -Force $wbDir | Out-Null

# ── 1. Sysmon ──────────────────────────────────────────────
Write-Host "[*] Downloading Sysmon..." -ForegroundColor Cyan
$sysmonZip = "$sysmonDir\Sysmon.zip"
if (-not (Test-Path "$sysmonDir\Sysmon64.exe")) {
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" `
        -OutFile $sysmonZip -UseBasicParsing
    Expand-Archive -Path $sysmonZip -DestinationPath $sysmonDir -Force
    Remove-Item $sysmonZip
}
Write-Host "[+] Sysmon ready at $sysmonDir" -ForegroundColor Green

# ── 2. Sysmon config (SwiftOnSecurity) ─────────────────────
Write-Host "[*] Downloading Sysmon config..." -ForegroundColor Cyan
$sysmonConfig = "$sysmonDir\sysmonconfig.xml"
if (-not (Test-Path $sysmonConfig)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" `
        -OutFile $sysmonConfig -UseBasicParsing
}
Write-Host "[+] Sysmon config ready" -ForegroundColor Green

# ── 3. Install Sysmon ──────────────────────────────────────
$svc = Get-Service Sysmon64 -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Host "[*] Installing Sysmon64..." -ForegroundColor Cyan
    & "$sysmonDir\Sysmon64.exe" -accepteula -i $sysmonConfig 2>$null
    Write-Host "[+] Sysmon64 installed" -ForegroundColor Green
} else {
    Write-Host "[=] Sysmon64 already installed, updating config..." -ForegroundColor Yellow
    & "$sysmonDir\Sysmon64.exe" -c $sysmonConfig 2>$null
}

# ── 4. Winlogbeat ──────────────────────────────────────────
Write-Host "[*] Downloading Winlogbeat 8.15.3..." -ForegroundColor Cyan
$wbZip = "$wbDir\winlogbeat.zip"
if (-not (Test-Path "$wbDir\winlogbeat.exe")) {
    Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-8.15.3-windows-x86_64.zip" `
        -OutFile $wbZip -UseBasicParsing
    Expand-Archive -Path $wbZip -DestinationPath $wbDir -Force
    # Move contents up one level
    $inner = Get-ChildItem "$wbDir\winlogbeat-*" -Directory | Select-Object -First 1
    if ($inner) {
        Get-ChildItem $inner.FullName | Move-Item -Destination $wbDir -Force
        Remove-Item $inner.FullName -Recurse -Force
    }
    Remove-Item $wbZip -ErrorAction SilentlyContinue
}
Write-Host "[+] Winlogbeat ready at $wbDir" -ForegroundColor Green

# ── 5. Winlogbeat config ──────────────────────────────────
Write-Host "[*] Writing winlogbeat.yml..." -ForegroundColor Cyan
$wbConfig = @"
winlogbeat.event_logs:
  - name: Microsoft-Windows-Sysmon/Operational
    processors:
      - script:
          lang: javascript
          source: >
            function process(evt) {
              evt.Put("event.module", "sysmon");
            }

  - name: Security
    processors:
      - script:
          lang: javascript
          source: >
            function process(evt) {
              evt.Put("event.module", "security");
            }

  - name: Microsoft-Windows-PowerShell/Operational
    event_id: 4103, 4104
    processors:
      - script:
          lang: javascript
          source: >
            function process(evt) {
              evt.Put("event.module", "powershell");
            }

output.elasticsearch:
  hosts: ["http://localhost:9200"]
  index: "winlogbeat-%{+yyyy.MM.dd}"

setup.template.name: "winlogbeat"
setup.template.pattern: "winlogbeat-*"
setup.ilm.enabled: false

logging.level: info
logging.to_files: true
logging.files:
  path: C:\Tools\siem\winlogbeat\logs
  name: winlogbeat
  keepfiles: 3
"@

$wbConfig | Out-File -FilePath "$wbDir\winlogbeat.yml" -Encoding utf8 -Force
Write-Host "[+] winlogbeat.yml written" -ForegroundColor Green

# ── 6. Install Winlogbeat service ──────────────────────────
$wbSvc = Get-Service winlogbeat -ErrorAction SilentlyContinue
if (-not $wbSvc) {
    Write-Host "[*] Installing Winlogbeat service..." -ForegroundColor Cyan
    & "$wbDir\install-service-winlogbeat.ps1" 2>&1
}

# ── 7. Start Winlogbeat ────────────────────────────────────
Write-Host "[*] Starting Winlogbeat..." -ForegroundColor Cyan
Start-Service winlogbeat -ErrorAction SilentlyContinue
Write-Host "[+] Winlogbeat started" -ForegroundColor Green

Write-Host ""
Write-Host "=== SIEM Setup Complete ===" -ForegroundColor Green
Write-Host "  Sysmon:     Installed (logging to Microsoft-Windows-Sysmon/Operational)"
Write-Host "  Winlogbeat: Shipping to http://localhost:9200 (index: winlogbeat-*)"
Write-Host ""
Write-Host "  Next: create a data view in Kibana for 'winlogbeat-*'"
Write-Host "  Then run the BOFs and check Discover for events."
