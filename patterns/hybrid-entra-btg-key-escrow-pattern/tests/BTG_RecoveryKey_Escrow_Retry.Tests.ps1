# =====================================================================
# Test File   : BTG_RecoveryKey_Escrow_Retry.Tests.ps1
# Description : Pester 5 unit tests for BTG_RecoveryKey_Escrow_Retry.ps1
# =====================================================================

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\BTG_RecoveryKey_Escrow_Retry.ps1'

    # Suppress file system and logging side effects across every test.
    # Add-Content is mocked here so individual tests can assert on it
    # via Should -Invoke with a -ParameterFilter.
    Mock Add-Content {}
    Mock New-Item   {}
    Mock Test-Path  { $true }

    # Default assumption: BackupToAAD cmdlet is available on the device.
    # Tests that cover the missing-cmdlet path override this in BeforeEach.
    Mock Get-Command {
        [PSCustomObject]@{ Name = 'BackupToAAD-BitLockerKeyProtector' }
    } -ParameterFilter { $Name -eq 'BackupToAAD-BitLockerKeyProtector' }
}

Describe 'BTG_RecoveryKey_Escrow_Retry.ps1' {

    # ------------------------------------------------------------------
    # 1. Pre-flight check
    # ------------------------------------------------------------------
    Describe 'Pre-flight: BackupToAAD cmdlet availability' {

        Context 'When BackupToAAD-BitLockerKeyProtector is not available on the device' {

            BeforeEach {
                Mock Get-Command { $null } -ParameterFilter {
                    $Name -eq 'BackupToAAD-BitLockerKeyProtector'
                }
                Mock Get-WinEvent {}
            }

            It 'exits without querying the BitLocker event log' {
                & $script:ScriptPath
                Should -Invoke Get-WinEvent -Times 0 -Exactly -Scope It
            }
        }
    }

    # ------------------------------------------------------------------
    # 2. No recent event
    # ------------------------------------------------------------------
    Describe 'Event log: no Event ID 846 present' {

        Context 'When Get-WinEvent returns nothing for Event ID 846' {

            BeforeEach {
                Mock Get-WinEvent { $null }
                Mock Get-BitLockerVolume {}
            }

            It 'exits cleanly without attempting to query the BitLocker volume' {
                & $script:ScriptPath
                Should -Invoke Get-BitLockerVolume -Times 0 -Exactly -Scope It
            }
        }
    }

    # ------------------------------------------------------------------
    # 3. Stale event guard
    # ------------------------------------------------------------------
    Describe 'Recency guard: stale event handling' {

        Context 'When the most recent Event ID 846 is 15 minutes old' {

            BeforeEach {
                Mock Get-WinEvent {
                    [PSCustomObject]@{
                        Id          = 846
                        TimeCreated = (Get-Date).AddMinutes(-15)
                        Message     = 'Failed to backup BitLocker Drive Encryption recovery information for volume E: to your Azure AD.'
                    }
                }
                Mock Get-BitLockerVolume {}
            }

            It 'skips processing without querying the BitLocker volume' {
                & $script:ScriptPath
                Should -Invoke Get-BitLockerVolume -Times 0 -Exactly -Scope It
            }

            It 'writes a stale event entry to the log' {
                & $script:ScriptPath
                Should -Invoke Add-Content -ParameterFilter {
                    $Value -match 'stale'
                } -Scope It
            }
        }
    }

    # ------------------------------------------------------------------
    # 4. Drive letter extraction — regex tested directly, no script call
    # ------------------------------------------------------------------
    Describe 'Drive letter extraction: regex pattern' {

        It 'extracts E: from a standard escrow failure message' {
            $msg = 'Failed to backup BitLocker Drive Encryption recovery information for volume E: to your Azure AD.'
            $msg -match 'volume\s+([A-Z]:)' | Should -BeTrue
            $Matches[1]                      | Should -Be 'E:'
        }

        It 'extracts D: from a message referencing volume D:' {
            $msg = 'Failed to backup BitLocker Drive Encryption recovery information for volume D: to your Azure AD.'
            $msg -match 'volume\s+([A-Z]:)' | Should -BeTrue
            $Matches[1]                      | Should -Be 'D:'
        }

        It 'does not match a message that contains no drive letter' {
            $msg = 'BitLocker encountered an unexpected error during the backup operation.'
            $msg -match 'volume\s+([A-Z]:)' | Should -BeFalse
        }
    }

    # ------------------------------------------------------------------
    # 5. GUID brace normalisation — pure logic, no script call needed
    # ------------------------------------------------------------------
    Describe 'GUID brace normalisation' {

        It 'wraps a bare GUID in curly braces' {
            $guid = '12345678-1234-1234-1234-123456789012'
            if ($guid -notmatch '^\{.+\}$') { $guid = "{${guid}}" }
            $guid | Should -Be '{12345678-1234-1234-1234-123456789012}'
        }

        It 'leaves a GUID already enclosed in curly braces unchanged' {
            $guid = '{12345678-1234-1234-1234-123456789012}'
            if ($guid -notmatch '^\{.+\}$') { $guid = "{${guid}}" }
            $guid | Should -Be '{12345678-1234-1234-1234-123456789012}'
        }
    }

    # ------------------------------------------------------------------
    # 6. Recency guard boundary conditions
    # ------------------------------------------------------------------
    Describe 'Recency guard: boundary conditions' {

        Context 'When the event is exactly 10 minutes old' {

            BeforeEach {
                Mock Get-WinEvent {
                    [PSCustomObject]@{
                        Id          = 846
                        TimeCreated = (Get-Date).AddMinutes(-10)
                        Message     = 'Failed to backup BitLocker Drive Encryption recovery information for volume E: to your Azure AD.'
                    }
                }
                Mock Get-BitLockerVolume {}
            }

            It 'treats the event as stale and skips processing' {
                & $script:ScriptPath
                Should -Invoke Get-BitLockerVolume -Times 0 -Exactly -Scope It
            }
        }

        Context 'When the event is 9 minutes old' {

            BeforeEach {
                Mock Get-WinEvent {
                    [PSCustomObject]@{
                        Id          = 846
                        TimeCreated = (Get-Date).AddMinutes(-9)
                        Message     = 'Failed to backup BitLocker Drive Encryption recovery information for volume E: to your Azure AD.'
                    }
                }
                # Return a volume with no protectors so the script exits cleanly
                # after confirming Get-BitLockerVolume was reached.
                Mock Get-BitLockerVolume {
                    [PSCustomObject]@{ KeyProtector = @() }
                }
            }

            It 'treats the event as recent and proceeds to query the BitLocker volume' {
                & $script:ScriptPath
                Should -Invoke Get-BitLockerVolume -Times 1 -Exactly -Scope It
            }
        }
    }
}
