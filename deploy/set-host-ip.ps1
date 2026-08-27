param(
    [string]$IP
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$varsFile = Join-Path $scriptDir "freeswitch\conf\etc\vars.xml"

if (-not (Test-Path -LiteralPath $varsFile)) {
    Write-Error "vars.xml not found: $varsFile"
    exit 1
}

if (-not $IP) {
    $candidates = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.InterfaceAlias -notlike "*Loopback*" -and
            $_.InterfaceAlias -notlike "Loopback*" -and
            $_.InterfaceAlias -notlike "vEthernet*" -and
            $_.InterfaceAlias -notlike "WSL*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -ne "127.0.0.1"
        } |
        Sort-Object InterfaceMetric -ErrorAction SilentlyContinue
    if (-not $candidates) {
        $candidates = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object {
                $_.InterfaceAlias -notlike "*Loopback*" -and
                $_.InterfaceAlias -notlike "Loopback*" -and
                $_.InterfaceAlias -notlike "vEthernet*" -and
                $_.InterfaceAlias -notlike "WSL*" -and
                $_.IPAddress -notlike "169.254.*" -and
                $_.IPAddress -ne "127.0.0.1"
            }
    }
    if (-not $candidates) {
        Write-Error "No usable IPv4 address found; pass -IP explicitly."
        exit 1
    }
    $IP = ($candidates | Select-Object -First 1).IPAddress
}

Write-Host "Chosen host IP: $IP"

$content = Get-Content -LiteralPath $varsFile -Raw
$pattern = '(<X-PRE-PROCESS cmd="set" data="external_(rtp|sip)_ip=)[^"]*("/>)'
$newContent = [regex]::Replace($content, $pattern, "`${1}$IP`${3}")

if ($newContent -eq $content) {
    Write-Host "vars.xml already up to date (no change needed)."
} else {
    Set-Content -LiteralPath $varsFile -Value $newContent -NoNewline -Encoding UTF8
    Write-Host "vars.xml updated: external_rtp_ip/external_sip_ip -> $IP"
}

Push-Location $scriptDir
try {
    docker compose restart freeswitch
    if ($LASTEXITCODE -ne 0) { Write-Error "docker compose restart failed"; exit 1 }
} finally {
    Pop-Location
}

Write-Host "Done. FreeSWITCH restarted with EXT-RTP-IP/EXT-SIP-IP = $IP"
