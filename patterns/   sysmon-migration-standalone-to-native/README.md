# Migrating Standalone Sysmon to Native Windows Sysmon

---
**Jump to section:**
[Strategic Overview](#strategic-overview) ·
[Architecture & Design](#architecture--design) ·
[Implementation Reference](#implementation-reference) ·
[Operational Guidance](#operational-guidance)

---

## Strategic Overview

Windows 11 24H2 and Windows Server 2025, with the March 2026 cumulative update (KB5079473) or later, ship Sysmon as a built-in optional feature. This pattern documents the cutover from standalone Sysinternals Sysmon to that native feature: the gated sequence that makes the switch safe on a running fleet, what actually happens to monitoring coverage during the switch, and how to recover when it doesn't go cleanly.

The case for migrating is servicing and support, not obsolescence. Standalone Sysmon isn't being deprecated. The Sysinternals build is still actively maintained and has, if anything, moved ahead in version number while fleets running standalone tend to sit further behind, since someone has to notice a new release and push the binary. Native Sysmon updates through the normal Windows Update cycle instead: security fixes land in the monthly release, and feature work goes out through preview updates first. Microsoft states that configuration survives a native binary update without needing to be reapplied. Microsoft has also been direct about the other half of the case: there's no official customer support path for running Sysmon in production as a third-party download, however well-established the tool is. Native Sysmon has one.

The two builds cannot run side by side. Microsoft doesn't support coexistence, and both register their kernel driver under the same name (`SysmonDrv`). So this is a real cutover (uninstall one, install the other), not a phased rollout where both run in parallel for a while. That constraint is what shapes everything else in this pattern: the migration has to be gated tightly enough that a machine never ends up in a state where neither build is running and nobody knows it.

This pattern also marks a deliberate departure from [Registry-Based Sysmon Configuration Deployment](https://github.com/Shirish03/windows-endpoint-security-patterns/blob/main/patterns/sysmon-configuration-via-native-policy), the pattern that got this fleet's standalone Sysmon configuration under policy control in the first place. That pattern pushes the compiled `Rules` registry value through Group Policy so configuration changes roll out without repackaging anything. For native Sysmon, this fleet is not carrying that approach forward. Configuration is supplied once, at migration time, via `sysmon.exe -i <config>`. Later configuration changes go out as a separate `sysmon.exe -c <config>` package rather than through the registry. The decision was driven by the Group Policy refresh delay that pattern already documents as a tradeoff. Testing then surfaced a second reason: the compiled rules blob is not compatible between Sysmon binary versions. In testing between standalone 14.16 and native, a blob compiled by one was rejected by the other, and if a rejected blob is the one in place at boot, the native Sysmon service logs two Event ID 255 errors and exits within about five seconds. That finding is detailed in [Operational Guidance](#operational-guidance), because anyone tempted to point their existing registry-based delivery pipeline at a native-migrated fleet needs to see it before they do.

## Architecture & Design

### Why this needs a gate, not just two commands

The obvious version of this migration is: enable the feature, uninstall standalone, install native. That sequence has a failure mode built into it. If the feature isn't actually ready when the uninstall runs, or if native's install fails for any reason after standalone is already gone, the machine sits with no Sysmon running and no monitoring. Nothing about that state is visible unless someone is watching the console at the right moment. Testing produced exactly this scenario by accident early on: a bug in an earlier version of the script crashed mid-uninstall and left a machine unmonitored for somewhere between 8½ and 15½ minutes. It was only caught because someone happened to be watching. No alert fired.

The design responds to that directly: nothing destructive happens until every precondition is confirmed, and once standalone removal starts, every subsequent failure is explicitly logged as a **gap state** (machine unmonitored) rather than folded into a generic error.

### The gated sequence

1. **Pre-checks.** The config file exists and parses as valid XML. The `Sysmon` optional feature exists on this OS build at all (it won't on 23H2, or on 24H2 without the required cumulative update). An inventory of whatever Sysmon is currently installed, classified by the image path of its Windows service, not by service name. A machine already migrated with this exact config exits cleanly with no changes made.

2. **Enable** the optional feature, skipped if it already reports Enabled.

3. **Gate.** Three conditions have to hold before anything is removed: the feature reports exactly `Enabled`, no restart is pending, and `System32\sysmon.exe` actually exists on disk. "No restart pending" checks more than the enable call's own `RestartNeeded` flag. It also checks the general Windows pending-reboot indicators (`CBS\RebootPending`, `WindowsUpdate\RebootRequired`), because other pending servicing work can block this just as easily as Sysmon's own enable call. `PendingFileRenameOperations` is logged but treated as advisory only. Browser and AV updaters leave entries there constantly: in testing, Chrome's updater entries reappeared within minutes of a reboot, so a gate that blocked on them kept returning 3010.

4. **Only if the gate passes**, uninstall standalone Sysmon, then poll until both its service and the `SysmonDrv` driver key are confirmed gone.

5. Install native Sysmon with the supplied config, then verify: the driver is running, the `Rules` registry value is present, and the registered `ConfigHash` matches the SHA-256 of the config that was supplied. Whether the `Sysmon` service is running and whether events reach the channel are logged as informational checks only, not failure conditions (see [Known limitations](#known-limitations-of-the-script)).

If the gate doesn't pass, standalone is never touched. If a failure happens after standalone removal has already started, it's labeled a gap state in the log every time, not just when it happens to be the failure someone is watching for.

### Classifying Sysmon installs by image path, not service name

Native Sysmon's Windows service is named `Sysmon`, the same name 32-bit standalone Sysmon uses. Any detection or classification logic built around service names will misidentify native as standalone. This pattern classifies by the service's actual binary path instead: `%WINDIR%\System32\sysmon.exe` is native, and `Sysmon64.exe` or a 32-bit `Sysmon.exe` anywhere else is standalone. The same classification is used for the "already migrated" short-circuit, for the uninstall target, and for the SCCM detection method described below.

One more wrinkle worth knowing about: `C:\Windows\Sysmon64.exe` stays on disk after `Sysmon64.exe -u force` removes the service. The uninstall removes the service and driver, not the binary file. Don't use the file's presence on disk as a signal that standalone is still installed; check the service instead.

## Implementation Reference

### Tested on

- Windows 11 Enterprise LTSC 24H2 (build 26100.9457), Hyper-V Gen 2 VM, and Windows 11 Pro 25H2 (build 26200.9457), physical. Native Sysmon 10.0.26100.8521 on both.
- Source: standalone Sysmon64 **v14.16** only. Configs at schema 4.00 and 4.22 both loaded unchanged on native.
- Run as a local administrator from an elevated Windows PowerShell 5.1 session. **Not yet run as SYSTEM under SCCM, and not tested on Windows Server 2025.**

### Before you migrate

- Search the config for `Sysmon64.exe`. Native's binary is `sysmon.exe`, so self-exclusion rules that match `Sysmon64.exe` won't exclude native's own activity. The script logs a warning if it finds a match but doesn't block.
- Native Sysmon's rendered event messages are localized to the device language (per Microsoft Learn); the XML event data is not. SIEM parsers that read rendered message text rather than event data may need updating on non-English devices.

### Exit codes

| Code | Meaning | Standalone touched? | Observed in testing |
|---|---|---|---|
| `0` | Migrated successfully, **or** already migrated with this exact config | Migrated: replaced by native. Already migrated: no changes | Yes, both |
| `3010` | Restart required before continuing | No | Yes |
| `4000` | Sysmon optional feature doesn't exist on this build | No | No (the empty result on 23H2 was observed manually) |
| `4001` | Config file missing or not valid XML | No | No |
| `4002` | Feature didn't reach Enabled and no restart is pending | No | No |
| `4003` | Feature reports Enabled but `sysmon.exe` is missing | No | No |
| `4004` | **Gap.** Standalone service still present after uninstall | Uninstall ran, native install skipped | No |
| `4005` | **Gap.** Native install ran but failed verification | Already removed (if it was present) | Yes (deliberately) |
| `4006` | Standalone service found, binary missing from disk, can't uninstall cleanly | No | No |
| `4007` | **Gap.** Standalone gone but `SysmonDrv` key still present (likely pending reboot) | Already removed | No |
| `4008` | An existing install doesn't match expectations (different config, feature not Enabled, binary missing) | No | Yes |
| `4999` | Unhandled error; the log states whether removal had started | Check the log | Only in an earlier script version |

### SCCM packaging

- **Requirement rule:** `Get-WindowsOptionalFeature -Online -FeatureName Sysmon` returns an object. This is the direct eligibility test rather than hardcoding a KB or build number, and it naturally excludes 23H2 and any 24H2 build that hasn't taken the required cumulative update.
- **Detection method:** a service exists whose image is `%WINDIR%\System32\sysmon.exe`, no service with a `sysmon.exe` or `sysmon64.exe` image exists anywhere else, and `SysmonDrv\Parameters\Rules` is present. This is the same image-path classification as the migration script itself. It deliberately doesn't check `ConfigHash`, since tying detection to one config version would mean every future config change needs an application revision, which defeats the point of shipping config changes as a separate package. Consider also requiring the `Sysmon` service to be **Running**: a machine whose service has stopped would then show up in deployment status instead of counting as installed.
- **Run as 64-bit PowerShell.** The script has no 64-bit check. In a 32-bit process, Windows redirects `System32` to `SysWOW64`, and the DISM cmdlets may fail as well. The script would then exit 4000 or 4003 without touching anything, which is safe but misleading. Keep the deployment type's "run as 32-bit process on 64-bit clients" option unchecked, and confirm it in the pilot.
- **Config delivery for the package:** by default the script looks for `sysmonconfig-export.xml` next to itself, matching how SCCM stages package content into its content cache. Either name the production config file that way or pass `-ConfigFileName`. `-ConfigPath` exists for manual and pilot use with an absolute path.
- `3010` maps to SCCM's standard soft-reboot exit code. Confirm the deployment re-runs the script automatically after the reboot rather than waiting for the next evaluation cycle.

### Migration script

`Migrate-SysmonToNative.ps1` is the gated script described above: [`scripts/Migrate-SysmonToNative.ps1`](scripts/Migrate-SysmonToNative.ps1). It is functionally identical to the tested version; only a code comment's spelling differs.

| File | Purpose |
|---|---|
| `scripts/Migrate-SysmonToNative.ps1` | The gated migration script. Self-contained, no dependencies beyond Windows PowerShell 5.1. Intended to run as an SCCM Application script with the config file staged alongside it, or manually via `-ConfigPath` for pilot testing. |

A PowerShell 5.1 quirk worth knowing if you're modifying it: a single `[pscustomobject]` returned from a function reports `.Count` as `$null`, not `1`. With exactly one standalone service present, that would silently skip the uninstall loop and go straight to installing native on top of a still-installed standalone build. Every call site that might return one object wraps it in `@()` for this reason; keep that pattern if you extend the script. A second one: standalone `Sysmon64.exe -u` writes a blank line to stderr, which Windows PowerShell 5.1 turns into a terminating error under `2>&1` with `$ErrorActionPreference = 'Stop'`. That was the bug behind the accidental gap described above; the script now runs native commands through a wrapper that avoids it.

### Known limitations of the script

These are deliberate scope limits of the tested version, not bugs. Each one was observed or reasoned from testing.

- **A failed native install is reported late.** The script doesn't check the exit code of `sysmon.exe -i`; it waits for its verification loop to time out (`-TimeoutSeconds`, default 30). In testing, a config native rejected failed in 45 ms, but the script reported 4005 about 32 seconds later.
- **The config isn't validated against native before standalone is removed.** Only XML well-formedness is checked. A config native rejects (for example, a schema version above what native supports) is discovered only after standalone is gone.
- **The `Sysmon` service being Running is not a pass condition,** either after install or in the "already migrated" check. Verification checks the driver, `Rules` and `ConfigHash`, which all still pass in the incompatible-blob outage described below.
- **No automatic restore of standalone** on a gap state.

## Operational Guidance

### What a clean migration looks like

A successful run completed in about 12 to 16 seconds end to end in testing (about 3 seconds of that is the enable call when the feature is still Disabled). The monitoring gap, the window between standalone's Sysmon service stopping and native's starting, measured consistently at 5 to 6 seconds across repeated runs. Sysmon's own Event ID 4 (service state change) is the reliable way to measure this yourself; Service Control Manager's event 7036 was never logged for either Sysmon service in testing.

The event log carries over unchanged. Native writes to the same `Microsoft-Windows-Sysmon/Operational` channel and the same `.evtx` file, so events written before the migration, including any not yet collected by Windows Event Forwarding or a SIEM agent, stay in place. On one migrated machine, the log's creation time and oldest events predate the migration by an hour, and the same file is still in use days later. The channel's size, retention mode and read permissions (`channelAccess`) were identical on a migrated machine and a standalone one, so forwarding access doesn't change. What is lost is only what happens during the switch itself: about 5 seconds in which no Sysmon events are captured.

### The restart check protects against a false green light

`Get-WindowsOptionalFeature` can report a feature as `Enabled` while the enable operation says a restart is still needed. Testing confirmed this directly: enabling Sysmon while another feature's restart was pending returned `RestartNeeded=True`, while both `Get-WindowsOptionalFeature` and `dism` reported the feature as `Enabled` at the same time. Relying on feature state alone would have proceeded into the uninstall with a restart still pending. The script's gate checks `RestartNeeded` and the general pending-reboot registry indicators specifically because feature state by itself isn't trustworthy here. If you're building your own tooling against this feature, don't skip that check to save a step.

In practice, a restart requirement during Sysmon's own enable call turned out to be rare: every clean test run returned `RestartNeeded=False`. When 3010 shows up in production, it's more likely to be other pending servicing work on the machine than anything Sysmon itself is doing.

### If native fails to install after standalone is removed (4005)

This was tested deliberately, with a config that is valid XML but that native rejects (an unsupported schema version):

- Native's install failed in 45 ms. The script logged `GAP STATE` and exited 4005 about 35 seconds after standalone's uninstall began, most of that spent in the verification loop.
- The machine was left with no Sysmon service, no driver and no config, and the `Microsoft-Windows-Sysmon/Operational` event channel no longer existed. Collectors reading that channel will see it as missing, not merely quiet.
- The gap doesn't end when the script exits. It lasts until someone acts on the 4005.

**Recovery:** the fastest known-good path is to reinstall standalone. `C:\Windows\Sysmon64.exe` is still on disk, and standalone installs cleanly while the native feature is Enabled (both verified in testing):

```powershell
C:\Windows\Sysmon64.exe -accepteula -i <known-good config.xml>
```

Alternatively, fix the config and re-run the migration script. With no standalone service and no `SysmonDrv` key left, it takes the fresh-install path. That path hasn't been exercised in testing.

### Rollback

Rolling back from native to standalone is a tested manual procedure; the script has no rollback mode.

```powershell
C:\Windows\System32\sysmon.exe -u
Sysmon64.exe -accepteula -i .\sysmonconfig-export.xml
```

Native's uninstall takes about 4 seconds and leaves the optional feature itself still `Enabled`. There's no need to disable it or reboot before reinstalling standalone. Standalone reinstalls cleanly on top of that with the same config and the same resulting `ConfigHash`. The monitoring gap for a rollback measured about the same as the forward migration, around 5 seconds. Re-running the forward migration script afterward picks up cleanly too: it detects the feature is already Enabled, skips the enable step, and proceeds straight to the standalone removal and native install. Rollback was tested with standalone 14.16 only, run as a local administrator.

### The gap state you don't want to cause yourself: incompatible rules blobs

The compiled `Rules` registry value carries a binary format version: 17 for standalone 14.16, 18 for native (and for standalone 15.22, whose layout nonetheless differs from native's). In testing between 14.16 and native, in both directions, a blob compiled by one was rejected by the other. Sysmon logged Event ID 255 ("incompatible") and kept running on its last good in-memory configuration. The registry kept the rejected blob and `ConfigHash` did not change. After a reboot, the result was a complete outage. About five seconds after boot, Sysmon logged two Event ID 255 entries ("incompatible", then "Failed to initialize the rule engine … Exit process"). The `Sysmon` service exited and was still Stopped more than two minutes later, and no other events were logged. The `SysmonDrv` driver showed as running throughout, so a health check that only looks at the driver reports the machine as healthy while it logs nothing.

**Recovery (verified):** `sysmon.exe -c <config.xml>` recompiles and reloads the configuration even with the service stopped. `Start-Service Sysmon` then restores monitoring.

This is not a live risk for a fleet that loads config only through `sysmon -i` at migration and `sysmon -c` afterwards, because both compile against the binary actually installed. It becomes a risk if a registry-based Rules push reaches native machines without matching the binary version, so don't reintroduce one without re-verifying compatibility. Native's binary is also updated by Windows Update. Microsoft states configuration is preserved across updates, but after the first cumulative update, confirm the `Sysmon` service is Running and events are flowing, not just that the driver is loaded.

### Detection and monitoring after migration

- Confirm the **`Sysmon` service is Running** and events are actually arriving, not just that `SysmonDrv` looks healthy. `sc query SysmonDrv` or `fltmc` can both report a healthy driver while the user-mode service has stopped logging anything.
- Alert on Sysmon Event ID 255 containing "incompatible" or "Exit process", and on hosts that go quiet for longer than expected. A host in a gap state may have no Sysmon channel at all.
- Update inventory and compliance tooling for the new service name (`Sysmon`, not `Sysmon64`), the new version numbering (`10.0.26100.x`, Windows-style, not Sysinternals-style), and the different driver path (`system32\drivers\sysmondrv.sys`).
- Track the rollout from data you already forward: Sysmon Event ID 4 (`State: Started`) records the version at every start. A host whose latest start shows `10.0.x` is migrated, and the event time is when. A host still on `14.16` hasn't migrated. A `14.16` `Stopped` event with no `10.0.x` start after it points to a gap state.
- After the fleet's first cumulative update following migration, spot-check a sample of machines: confirm the `Sysmon` service is Running, `sysmon -c` lists the expected rules, and there are no Event ID 255 entries.

### Checking the native Sysmon version

Native Sysmon uses Windows version numbering (for example `10.0.26100.8521`), not Sysinternals numbering (`14.16`, `15.22`), and the two aren't comparable. Neither `sysmon.exe -?` nor `dism /online /get-featureinfo /featurename:Sysmon` shows a version. Two methods that do:

```powershell
# Version on disk: use this for inventory. It changes when a cumulative update replaces the binary.
(Get-Item C:\Windows\System32\sysmon.exe).VersionInfo | Select-Object FileVersion, ProductVersion, ProductName

# Version actually running: Sysmon logs Event ID 4 with its version and schema every time it starts.
Get-WinEvent -FilterHashtable @{ LogName='Microsoft-Windows-Sysmon/Operational'; Id=4 } -MaxEvents 1 |
    Select-Object TimeCreated, @{n='Details';e={ ($_.Message -split "`r?`n" | Select-String 'State|Version') -join ' | ' }}
```

On a migrated machine, the channel holds both versions: standalone's Event ID 4 (`Version: 14.16`, `SchemaVersion: 4.83`) from before the migration, followed by native's (`Version: 10.0.26100.8521`, `SchemaVersion: 4.91`). The schema version is the highest config schema that binary accepts; `sysmon.exe -i` or `-c` also prints it as `Sysmon schema version`.

### Rolling this out

Pilot through SCCM on a small number of machines before a broader push. Everything above was validated running as a local administrator. Running as SYSTEM under SCCM has not been exercised yet, and it's the first thing to confirm in the pilot: that the script runs as a 64-bit process, that the config is found in the SCCM content cache, that 3010 is handled as a soft reboot followed by an automatic re-run, and that the event collector keeps receiving new Sysmon events from each migrated machine. Confirm exit codes are surfacing correctly in SCCM deployment status before scaling past that pilot.

## Related Patterns

- **[Registry-Based Sysmon Configuration Deployment](https://github.com/Shirish03/windows-endpoint-security-patterns/blob/main/patterns/sysmon-configuration-via-native-policy)**: the pattern this one migrates a fleet away from. Read it first for the standalone-era configuration approach and the Group Policy refresh tradeoff that motivated this pattern's own configuration-delivery decision.

---

## Disclaimer

This pattern is provided as reference material and design guidance.
Implementations may require adaptation based on environment, Sysmon
version, and Windows servicing state.

Validate all configurations, including the migration script itself,
in a controlled test environment before production use.
