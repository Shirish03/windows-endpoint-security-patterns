# =====================================================================
# Script Name : Install-BTGRecoveryKeyEscrow.ps1
# Author      : Shirish
#
# Description :
# Deploys the BitLocker-to-Go recovery key escrow retry solution by:
#   1. Copying the PowerShell script to ProgramData
#   2. Registering an event-triggered scheduled task (Event ID 846)
#      using the provided XML file
#
# =====================================================================

[CmdletBinding()]
param()

# -------------------------------
# Variables
# -------------------------------
$ScriptSourceName = "BTG_RecoveryKey_Escrow_Retry.ps1"
$TargetScriptDir  = "$env:ProgramData\BitLocker\Scripts"
$TargetScriptPath = Join-Path $TargetScriptDir $ScriptSourceName

$LogRoot       = "$env:ProgramData\BitLocker\Logs"
$InstallLogFile = Join-Path $LogRoot "Install.log"

if (-not (Test-Path $LogRoot)) {
    New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
}

function Write-InstallLog {
    param([Parameter(Mandatory)][string]$Message)
    $Entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') : $Message"
    Add-Content -Path $InstallLogFile -Value $Entry
    Write-Output $Entry
}

$TaskXmlName = "BitLockerToGo-Escrow-Retry.xml"
$TaskXmlPath = Join-Path $PSScriptRoot "..\tasks\$TaskXmlName"

if (Test-Path $TaskXmlPath) {
    $TaskXmlPath = (Resolve-Path $TaskXmlPath).Path
} else {
    Write-Error "Scheduled Task XML not found! Please ensure it exists at: $TaskXmlPath"
    exit 1
}


$TaskName         = "BitLockerToGo-RecoveryKey-Escrow-Retry"

Write-InstallLog "===== Install-BTGRecoveryKeyEscrow started ====="

# -------------------------------
# Ensure Script Directory Exists
# -------------------------------
if (-not (Test-Path $TargetScriptDir)) {
    Write-Output "Creating script directory at $TargetScriptDir"
    New-Item -Path $TargetScriptDir -ItemType Directory -Force | Out-Null
}

# -------------------------------
# Copy Main Script
# -------------------------------
$SourceScriptPath = Join-Path $PSScriptRoot $ScriptSourceName
if (-not (Test-Path $SourceScriptPath)) {
    Write-Error "Source script not found: $SourceScriptPath"
    exit 1
}

Write-Output "Copying $ScriptSourceName to $TargetScriptPath"
try {
    Copy-Item -Path $SourceScriptPath -Destination $TargetScriptPath -Force -ErrorAction Stop
    Write-InstallLog "Script copied to $TargetScriptPath"
}
catch {
    $Msg = "ERROR: Failed to copy script to $TargetScriptPath : $($_.Exception.Message)"
    Write-Error $Msg
    Write-InstallLog $Msg
    exit 1
}

# -------------------------------
# Remove Existing Scheduled Task (if any)
# -------------------------------
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Output "Existing task found. Removing $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# -------------------------------
# Register Scheduled Task using XML
# -------------------------------
Write-Output "Importing Scheduled Task from XML: $TaskXmlPath"
schtasks.exe /Create /TN "$TaskName" /XML "$TaskXmlPath" /F

if ($LASTEXITCODE -ne 0) {
    $Msg = "ERROR: schtasks.exe failed with exit code $LASTEXITCODE"
    Write-Error $Msg
    Write-InstallLog $Msg
    exit 1
}

Write-InstallLog "Scheduled task '$TaskName' registered successfully."
Write-InstallLog "===== Install-BTGRecoveryKeyEscrow completed successfully ====="
