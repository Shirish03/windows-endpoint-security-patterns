# Event ID 846 – BitLocker Recovery Key Backup Failure

## Overview

Event ID 846 is logged by the BitLocker API when a recovery key backup
to Entra ID (Azure AD) fails. It is emitted in the
`Microsoft-Windows-BitLocker-API/Management` channel and is the primary
signal that drives the escrow retry automation in this pattern.

This document shows what the event looks like in Windows Event Viewer,
identifies the fields the script extracts, and provides a comparison
with the corresponding success event.

---

## Log Channel

```
Microsoft-Windows-BitLocker-API/Management
```

**Event Viewer navigation path:**
`Applications and Services Logs → Microsoft → Windows → BitLocker-API → Management`

> **Note:** An earlier version of the escrow script incorrectly referenced
> `Microsoft-Windows-BitLocker/BitLocker Management`, which does not exist
> as a valid channel and would cause `Get-WinEvent` to silently return
> nothing on every execution. The correct channel is
> `Microsoft-Windows-BitLocker-API/Management`, consistent with what is
> shown in the README and architecture documentation.

---

## Sample Event — XML View

As displayed in Windows Event Viewer (Details → XML View).
All identity-bearing values are sanitized.

```xml
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <System>
    <Provider Name="Microsoft-Windows-BitLocker-API"
              Guid="{9C88D4AD-0F66-4E89-A34A-5A68B27A8B62}" />
    <EventID>846</EventID>
    <Version>0</Version>
    <Level>3</Level>
    <Task>0</Task>
    <Opcode>0</Opcode>
    <Keywords>0x4000000000000000</Keywords>
    <TimeCreated SystemTime="2024-11-12T14:23:07.445Z" />
    <EventRecordID>2847</EventRecordID>
    <Correlation />
    <Execution ProcessID="1472" ThreadID="2356" />
    <Channel>Microsoft-Windows-BitLocker-API/Management</Channel>
    <Computer>CORP-PC-0042</Computer>                        <!-- sanitized -->
    <Security UserID="S-1-5-18" />                          <!-- SYSTEM -->
  </System>
  <EventData>
    <Data Name="VolumeMountPoint">E:</Data>                  <!-- removable drive -->
    <Data Name="volumeId">{00000000-0000-0000-0000-000000000001}</Data>
    <Data Name="RecoveryKeyId">{00000000-0000-0000-0000-000000000002}</Data>
  </EventData>
</Event>
```

**Level 3 = Warning.** BitLocker treats a backup failure as a warning rather
than a hard error — there is no automatic retry and no user-facing alert,
which is why the failure is easy to miss without explicit log monitoring.

---

## Sample Event — Message View

As displayed in Windows Event Viewer (General tab / rendered message).

```
Failed to backup BitLocker Drive Encryption recovery information for
volume E: to your Azure AD.
TracId: {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
```

The `TracId` GUID identifies the specific backup operation and is
unrelated to the recovery key itself.

---

## Field Extraction — What the Script Uses and Why

The escrow script works from the rendered `Message` property of the event
object rather than raw `EventData` fields. This is because
`Get-WinEvent` returns a fully rendered message string that reflects
what Event Viewer displays, making it stable across Windows versions.

### Drive Letter Extraction

```powershell
if ($Event.Message -match "volume\s+([A-Z]:)") {
    $DriveLetter = $Matches[1]
}
```

| Element | Value | Source |
|---------|-------|--------|
| Pattern matched | `volume E:` | `$Event.Message` |
| Captured group `[1]` | `E:` | `$Matches[1]` |

The regex `volume\s+([A-Z]:)` matches the literal string "volume" followed
by optional whitespace and a single uppercase drive letter with colon.
This is intentionally narrow: it targets only the drive letter fragment
in the message and rejects any match that doesn't conform to standard
Windows drive letter format.

### Other Event Properties Used

| Property | Value | Purpose |
|----------|-------|---------|
| `$Event.TimeCreated` | `2024-11-12 14:23:07` | Logged for audit context; used by recency guard |
| `$Event.Id` | `846` | Filtered at query time via `Get-WinEvent` |

The script does **not** use `EventData` fields (`VolumeMountPoint`,
`volumeId`, `RecoveryKeyId`) directly. The drive letter from the message
string is sufficient to identify the volume, and recovery key protectors
are enumerated fresh from the live BitLocker state via
`Get-BitLockerVolume` rather than trusting event metadata.

---

## Normal vs Failure — Event Comparison

| | Event ID 845 (Success) | Event ID 846 (Failure) |
|-|------------------------|------------------------|
| **Meaning** | Recovery key backup to Entra ID succeeded | Recovery key backup to Entra ID failed |
| **Level** | 4 — Information | 3 — Warning |
| **Visibility** | No alert; logged silently | No alert; logged silently |
| **User notification** | None | None |
| **Intune reporting** | May not surface immediately | May not surface immediately |
| **Action required** | None | Retry escrow — this pattern |

Both events are logged to `Microsoft-Windows-BitLocker-API/Management`.

**The critical operational detail:** neither event generates a user-facing
notification or a reliable Intune compliance signal on Hybrid Entra ID
joined devices. A device that consistently logs Event ID 846 with no
corresponding 845 has no escrowed recovery key — silently, and without
any alert. This is the gap the pattern closes.

---

## Querying the Event Manually

To retrieve the most recent Event ID 846 from PowerShell:

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-BitLocker-API/Management'
    Id      = 846
} -MaxEvents 5
```

To check for both success and failure events on a given drive:

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-BitLocker-API/Management'
    Id      = 845, 846
} -MaxEvents 20 | Select-Object TimeCreated, Id, Message
```
