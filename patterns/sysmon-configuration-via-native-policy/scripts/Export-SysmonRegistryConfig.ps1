<#
.SYNOPSIS
    Exports the compiled Sysmon registry configuration as a deployment artifact.

.DESCRIPTION
    Sysmon persists its compiled configuration to
    HKLM\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters\Rules as a
    REG_BINARY value. This script extracts that value and writes it as a
    standard .reg file — the versioned artifact used when configuring a Group
    Policy Preferences registry item to distribute the configuration to endpoints.

    Optionally imports a Sysmon XML configuration before extraction, so the
    full reference-system workflow runs as a single step.

.PARAMETER OutputPath
    Directory where output files are written. Created if it does not exist.
    Defaults to the current directory.

.PARAMETER ConfigXmlPath
    Optional. Path to a Sysmon XML configuration file to import before
    extraction. Requires Sysmon to be installed and sysmon.exe to be on the
    PATH or specified via -SysmonPath.

.PARAMETER SysmonPath
    Path to the Sysmon executable. Defaults to sysmon.exe (resolved from PATH).
    Only used when -ConfigXmlPath is specified.

.EXAMPLE
    .\Export-SysmonRegistryConfig.ps1 -OutputPath C:\SysmonArtifacts
    Extracts the currently loaded configuration and writes output to
    C:\SysmonArtifacts.

.EXAMPLE
    .\Export-SysmonRegistryConfig.ps1 -ConfigXmlPath .\sysmonconfig.xml -OutputPath C:\SysmonArtifacts
    Imports sysmonconfig.xml, then exports the compiled configuration.

.NOTES
    Must run as Administrator. Sysmon must be installed on the reference system.
    The output .reg file is the artifact to reference when configuring the Group
    Policy Preferences registry item. See the pattern documentation for full
    GPO deployment guidance.
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = (Get-Location).Path,

    [Parameter()]
    [string]$ConfigXmlPath = '',

    [Parameter()]
    [string]$SysmonPath = 'sysmon.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RegistryKeyPath   = 'HKLM:\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters'
$RegistryValueName = 'Rules'
$Timestamp         = Get-Date -Format 'yyyyMMdd-HHmmss'
$ExitCode          = 0

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    Write-Output ('[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message)
}

try {
    # Ensure output directory exists
    if (-not (Test-Path -Path $OutputPath -PathType Container)) {
        Write-Log "Creating output directory: $OutputPath"
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    # Optional: import XML config before extraction
    if ($ConfigXmlPath -ne '') {
        if (-not (Test-Path -Path $ConfigXmlPath -PathType Leaf)) {
            Write-Log "Config file not found: $ConfigXmlPath" -Level ERROR
            $ExitCode = 1
            return
        }

        $resolvedSysmon = Get-Command $SysmonPath -ErrorAction SilentlyContinue
        if (-not $resolvedSysmon) {
            Write-Log "Sysmon executable not found: $SysmonPath" -Level ERROR
            Write-Log "Install Sysmon or provide the full path via -SysmonPath." -Level ERROR
            $ExitCode = 1
            return
        }

        Write-Log "Importing configuration: $ConfigXmlPath"
        $sysmonOut = & ($resolvedSysmon.Source) -c $ConfigXmlPath -accepteula 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "sysmon.exe -c exited $LASTEXITCODE`: $sysmonOut" -Level ERROR
            $ExitCode = 1
            return
        }
        Write-Log "Configuration imported."
    }

    # Verify Sysmon is installed and configured
    if (-not (Test-Path -Path $RegistryKeyPath)) {
        Write-Log "Registry key not found: $RegistryKeyPath" -Level ERROR
        Write-Log "Verify Sysmon is installed and configured on this system." -Level ERROR
        $ExitCode = 1
        return
    }

    $rulesProperty = Get-ItemProperty -Path $RegistryKeyPath -Name $RegistryValueName -ErrorAction SilentlyContinue
    if ($null -eq $rulesProperty) {
        Write-Log "Value '$RegistryValueName' not present at $RegistryKeyPath" -Level ERROR
        Write-Log "Sysmon may be installed but not yet configured. Run: sysmon.exe -c <config.xml>" -Level ERROR
        $ExitCode = 1
        return
    }

    [byte[]]$rulesBytes = $rulesProperty.$RegistryValueName
    $byteCount = $rulesBytes.Length
    Write-Log "Extracted $byteCount bytes from $RegistryKeyPath\$RegistryValueName"

    # SHA-256 for version comparison and change tracking
    $sha256    = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash($rulesBytes)
    $hashHex   = ($hashBytes | ForEach-Object { '{0:x2}' -f $_ }) -join ''
    Write-Log "SHA-256: $hashHex"

    # Build .reg hex block — 25 bytes per line, regedit line-continuation format
    $hexPairs  = $rulesBytes | ForEach-Object { '{0:x2}' -f $_ }
    $lineWidth = 25
    $regLines  = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $hexPairs.Count; $i += $lineWidth) {
        $end = [Math]::Min($i + $lineWidth - 1, $hexPairs.Count - 1)
        $regLines.Add(($hexPairs[$i..$end] -join ','))
    }
    $regHexBlock = $regLines -join (",\`r`n  ")

    $regKeyLiteral = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters'
    $regContent    = "Windows Registry Editor Version 5.00`r`n`r`n[$regKeyLiteral]`r`n`"$RegistryValueName`"=hex:$regHexBlock`r`n"

    # Write .reg artifact (Unicode encoding required by regedit)
    $baseName    = "SysmonRules-$Timestamp"
    $regFilePath = Join-Path $OutputPath "$baseName.reg"
    [System.IO.File]::WriteAllText($regFilePath, $regContent, [System.Text.Encoding]::Unicode)
    Write-Log "Written: $regFilePath"

    # Write deployment summary
    $metaFilePath = Join-Path $OutputPath "$baseName.txt"
    $metaLines    = @(
        "Sysmon Registry Export",
        "Timestamp : $Timestamp",
        "Hostname  : $env:COMPUTERNAME",
        "Key       : $RegistryKeyPath",
        "Value     : $RegistryValueName",
        "Bytes     : $byteCount",
        "SHA-256   : $hashHex",
        "",
        "GPO Deployment (Group Policy Preferences > Registry)",
        "  Action     : Replace",
        "  Hive       : HKEY_LOCAL_MACHINE",
        "  Key path   : SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters",
        "  Value name : $RegistryValueName",
        "  Value type : REG_BINARY",
        "  Value data : (hex content from $baseName.reg)",
        "",
        "Diff successive exports to review configuration changes before",
        "distributing a new policy version."
    )
    [System.IO.File]::WriteAllText($metaFilePath, ($metaLines -join "`r`n"), [System.Text.Encoding]::UTF8)
    Write-Log "Written: $metaFilePath"

    Write-Log "Export complete."

} catch {
    Write-Log "Unhandled error: $_" -Level ERROR
    $ExitCode = 1
} finally {
    exit $ExitCode
}
