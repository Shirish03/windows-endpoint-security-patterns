# =====================================================================
# Script Name : BTG_RecoveryKey_Escrow_Retry.ps1
# Author      : Shirish
#
# Description :
# This script addresses a BitLocker-to-Go recovery key escrow
# design limitation observed in Hybrid Entra ID and Intune-managed
# Windows environments.
#
# When Event ID 846 (BitLocker recovery key backup failure) is logged,
# the script:
#   - Identifies the affected removable volume
#   - Locates RecoveryPassword key protectors
#   - Retries backing up the recovery information to Entra ID
#
# The script is event-driven, user-independent, and designed to
# demonstrate a design-focused approach to improving recovery key
# governance for removable media.
#
# Logging :
# All actions and errors are logged to:
#   C:\ProgramData\BitLocker\Logs\
#
# Notes :
# - Requires BackupToAAD-BitLockerKeyProtector cmdlet
# - Intended for reference and educational use
#
# =====================================================================

[CmdletBinding()]
param()

# -------------------------------
# Configuration
# -------------------------------
$ScriptName    = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$ScriptVersion = "1.2"

$LogRoot = "$env:ProgramData\BitLocker\Logs"
$LogFile = Join-Path $LogRoot "$ScriptName.log"

if (-not (Test-Path $LogRoot)) {
    New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
}

# -------------------------------
# Logging Function
# -------------------------------
function Write-Log {
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Timestamp : $Message"
}

# -------------------------------
# Pre-flight Check
# -------------------------------
if (-not (Get-Command BackupToAAD-BitLockerKeyProtector -ErrorAction SilentlyContinue)) {
    Write-Log "ERROR: Required cmdlet 'BackupToAAD-BitLockerKeyProtector' is not available on this device."
    exit 1
}

$ExitCode = 0

Write-Log "===== Script Execution Started (Version $ScriptVersion) ====="

try {
    # ------------------------------------------------------------
    # Retrieve the most recent BitLocker-to-Go backup failure event
    # ------------------------------------------------------------
    $Event = Get-WinEvent -FilterHashtable @{
        LogName = 'Microsoft-Windows-BitLocker/BitLocker Management'
        Id      = 846
    } -MaxEvents 1 -ErrorAction SilentlyContinue

    if (-not $Event) {
        Write-Log "No recent Event ID 846 found in the BitLocker Management log."
        $ExitCode = 0
        return
    }

    Write-Log "Processing BitLocker event logged at $($Event.TimeCreated)"

    # ------------------------------------------------------------
    # Recency guard: skip stale events
    # ------------------------------------------------------------
    $EventAge = (Get-Date) - $Event.TimeCreated
    if ($EventAge.TotalMinutes -gt 10) {
        Write-Log "Event is $([math]::Round($EventAge.TotalMinutes, 1)) minutes old; skipping stale event."
        $ExitCode = 0
        return
    }

    # ------------------------------------------------------------
    # Extract drive letter from event message
    # ------------------------------------------------------------
    if ($Event.Message -match "volume\s+([A-Z]:)") {

        $DriveLetter = $Matches[1]
        Write-Log "Identified removable volume: $DriveLetter"
        Write-Log "DEBUG: About to call Get-BitLockerVolume"

        # --------------------------------------------------------
        # Retrieve BitLocker volume information
        # --------------------------------------------------------
        $BitLockerVolume = Get-BitLockerVolume -MountPoint $DriveLetter
        Write-Log "DEBUG: Get-BitLockerVolume succeeded"

        $RecoveryProtectors = $BitLockerVolume.KeyProtector |
            Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }
        Write-Log "DEBUG: Protector filter complete, found $($RecoveryProtectors.Count) protector(s)"

        if (-not $RecoveryProtectors) {
            Write-Log "ERROR: No RecoveryPassword key protectors found on volume $DriveLetter"
            $ExitCode = 1
            return
        }

        # --------------------------------------------------------
        # Attempt escrow for each RecoveryPassword protector
        # --------------------------------------------------------
        foreach ($Protector in $RecoveryProtectors) {

            $KeyProtectorId = $Protector.KeyProtectorId.ToString()

            # Ensure GUID is enclosed in braces
            if ($KeyProtectorId -notmatch '^\{.+\}$') {
                $KeyProtectorId = "{${KeyProtectorId}}"
            }

            try {
                Write-Log "Attempting recovery key escrow for $DriveLetter (ProtectorId: $KeyProtectorId)"
                BackupToAAD-BitLockerKeyProtector `
                    -MountPoint $DriveLetter `
                    -KeyProtectorId $KeyProtectorId `
                    -ErrorAction Stop

                Write-Log "SUCCESS: RecoveryPassword protector escrowed successfully ($KeyProtectorId)"
            }
            catch {
                $ExitCode = 1
                Write-Log "ERROR: Escrow attempt failed for protector $KeyProtectorId on $DriveLetter : $($_.Exception.Message)"
            }
        }
    }
    else {
        $ExitCode = 1
        Write-Log "ERROR: Failed to extract drive letter from event message."
        Write-Log "Event message content: $($Event.Message)"
    }
}
catch {
    $ExitCode = 1
    Write-Log "UNHANDLED ERROR: $($_.Exception.Message)"
}
finally {
    Write-Log "===== Script Execution Finished ====="
    exit $ExitCode
}
