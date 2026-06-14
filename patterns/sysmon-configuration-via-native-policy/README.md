# Registry-Based Sysmon Configuration Deployment

---
**Jump to section:**
[Strategic Overview](#strategic-overview) ·
[Architecture & Design](#architecture--design) ·
[Implementation Reference](#implementation-reference) ·
[Operational Guidance](#operational-guidance)

---

## Strategic Overview

### Who Should Read This

This document serves two audiences. Security architects and IT leadership
will find the strategic context, risk framing, and architectural
recommendation in this section. Engineers responsible for deploying and
operating the solution should proceed to
[Architecture & Design](#architecture--design) for design rationale,
[Implementation Reference](#implementation-reference) for deployment
steps, and [Operational Guidance](#operational-guidance) for monitoring
and failure handling.

---

### The Problem in Plain Terms

Sysmon's detection coverage is only as current as its configuration. In
environments where configuration updates are bundled with the Sysmon
binary and delivered through software deployment pipelines, every
detection improvement requires a software deployment cycle, introducing
lag, change management overhead, and an unnecessary coupling between two
lifecycles. The binary changes rarely; the configuration should change
frequently. Binding them together slows detection iteration without any
security benefit.

When a deployment fails silently, as software deployments sometimes do,
the endpoint continues running an outdated configuration with no
indication that the intended update was not applied.

---

### Risk and Compliance Implications

**Detection engineering velocity**
Threat coverage gaps accumulate when configuration updates are delayed
by deployment cycles. A detection rule update that would close a known
gap takes days or weeks instead of hours when it must travel through a
software packaging and deployment pipeline. Over time, this lag becomes
a structural limit on how quickly the organisation can respond to
emerging threats.

**Configuration drift**
Silent deployment failures leave endpoints running outdated
configurations indefinitely. Without a mechanism to verify that the
intended configuration version is active across the fleet, drift is
invisible until a detection gap becomes evident through a missed event.

**Audit and version confirmation**
Confirming which Sysmon configuration version is active on a given
endpoint requires either querying the endpoint directly or trusting
deployment records. Neither is reliable at scale. This creates an audit
gap in environments where Sysmon configuration is a documented security
control.

---

### Architectural Recommendation

Decouple Sysmon configuration delivery from binary deployment by
treating the registry-backed configuration as the authoritative
deployment artifact. Distribute updates via native Group Policy or Intune
Policy CSP registry targeting (mechanisms already present in the
environment that report application status and operate independently of
the software deployment pipeline).

---

## Architecture & Design

### Background

Sysmon is a host-based telemetry tool that extends native Windows event
logging with detailed visibility into process execution, network
connections, file system activity, and other system behaviours.

While the Sysmon binary itself is typically deployed once and remains
stable, its configuration defines what is observed and how events are
generated. Detection strategies evolve over time (in response to new
threats, operational changes, and tuning requirements), making Sysmon
configuration a living artifact that requires ongoing updates.

In many environments, configuration updates are bundled with the Sysmon
binary and delivered through software deployment pipelines. While
functional, this creates unnecessary coupling between binary lifecycle
management and configuration changes, slowing down detection iteration.

---

### Key Observation

When a Sysmon XML configuration is imported, Windows persists the
compiled configuration to the registry:

- **Key:** `HKLM\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters`
- **Value:** `Rules`
- **Type:** `REG_BINARY`

Sysmon reads from this registry representation at runtime, not from the
original XML file. This behaviour makes it possible to manage Sysmon
configuration independently from the Sysmon binary, using native Windows
policy delivery mechanisms.

---

### Solution Overview

This pattern decouples Sysmon configuration delivery from binary
deployment by treating the registry-backed configuration as the
authoritative artifact and distributing it via centralised policy.

```mermaid
flowchart TB
    subgraph S1["① Reference system"]
        A["Validated Sysmon\nXML config file"]
        B["sysmon.exe -c config.xml\nConfiguration imported"]
        A --> B
    end

    subgraph S2["② Registry extraction"]
        C["HKLM\\SYSTEM\\CurrentControlSet\nServices\\SysmonDrv\\Parameters\nRules  —  REG_BINARY\nextracted as deployment artifact"]
    end

    subgraph S3["③ Policy distribution"]
        D["Group Policy Object\nor Intune Policy CSP\nRegistry preference targeting\nSysmonDrv\\Rules\nNo agents required"]
    end

    subgraph S4["④ Target endpoints"]
        E["Standard policy refresh cycle\nNo manual steps"]
        F["Registry value applied to endpoint"]
        G["Sysmon reads updated configuration\nat runtime  —  binary unchanged"]
        E --> F --> G
    end

    S1 --> S2
    S2 --> S3
    S3 --> S4
```

---

### Key Design Principles

| Principle | Description |
|---|---|
| **Decoupled lifecycles** | Configuration updates travel independently of binary deployment |
| **Native mechanisms only** | Group Policy and Intune Policy CSP require no additional tooling or agents |
| **Registry as source of truth** | The compiled registry value is the deployment artifact, not the XML file |
| **Policy-cadence delivery** | Updates reach endpoints at standard policy refresh intervals |
| **Auditable** | Policy application status is reported by the policy infrastructure; registry values are queryable at scale |

---

### Design Trade-offs and Alternatives Considered

**Why registry distribution rather than script-based deployment?**
Script-based approaches (running `sysmon.exe -c config.xml` via a
scheduled task or remote execution tool) reintroduce binary-style
deployment dependencies: the script must run, the file must be present,
and execution must succeed. Registry policy distribution uses
infrastructure already operating in the environment with built-in
application reporting.

**Why not manage Sysmon configuration via a dedicated SIEM or EDR agent?**
Where a SIEM or EDR platform provides native Sysmon configuration
management, that path is preferable. This pattern is designed for
environments where no such platform is available or where Sysmon is
managed independently of the primary telemetry pipeline.

---

### Repository Contents

| File | Purpose |
|---|---|
| `scripts/Export-SysmonRegistryConfig.ps1` | Extracts compiled Sysmon configuration from the registry on a reference system; writes a `.reg` file ready for GPO configuration; optionally imports XML before extraction |
| `docs/registry-based-sysmon-config.md` | Detailed documentation covering the registry model, step-by-step approach, benefits, and operational considerations |

---

## Implementation Reference

### Environment Requirements

| Requirement | Detail |
|---|---|
| **Sysmon** | Installed and running on reference system; version consistent with target endpoints |
| **Reference system** | Domain-joined Windows 10/11 or Server; used for config validation and registry extraction |
| **Policy infrastructure** | Group Policy (domain-joined) or Intune Policy CSP (Intune-managed) |
| **PowerShell** | Windows PowerShell 5.1 for extraction script |
| **Permissions** | Local administrator on reference system; GPO edit rights or Intune configuration profile rights for distribution |

---

### Deployment Steps

**1. Validate configuration on a reference system**

Load the XML configuration on a controlled reference machine:

```powershell
sysmon.exe -c config.xml
```

Confirm the configuration is syntactically correct and behaviourally
intentional before extraction.

**2. Extract the compiled registry value**

Run the extraction script on the reference system:

```powershell
.\Export-SysmonRegistryConfig.ps1
```

This reads the `Rules` value from
`HKLM\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters`, writes
a `.reg` file in standard regedit format, and outputs a SHA-256 hash
for version tracking. See
[`docs/registry-based-sysmon-config.md`](docs/registry-based-sysmon-config.md)
for field values and GPO deployment guidance.

**3. Deploy via Group Policy or Intune**

Embed the binary registry value in a Group Policy preference or Intune
Policy CSP profile targeting:

```
Key:   HKLM\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters
Value: Rules
Type:  REG_BINARY
```

No additional tooling or agents are required. Target systems receive
the update during standard policy refresh cycles.

---

### Validation

After policy distribution, confirm the registry value is applied on a
target endpoint:

```powershell
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters" |
    Select-Object -ExpandProperty Rules |
    ForEach-Object { [System.BitConverter]::ToString($_) }
```

Cross-reference the output against the SHA-256 hash produced by the
extraction script to confirm version consistency.

To verify Sysmon is reading the updated configuration at runtime:

```powershell
sysmon.exe -c
```

This prints the active configuration summary without modifying it.

---

## Operational Guidance

### Verifying Registry Values Are Applied

After policy distribution, query the target registry path directly:

```
HKLM\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters\Rules
```

The value type is `REG_BINARY`. To confirm a specific version is active,
compare the SHA-256 hash of the deployed value against the hash output
by `Export-SysmonRegistryConfig.ps1` at extraction time. A mismatch
indicates the policy has not yet applied or was not applied successfully.

At scale, use Group Policy results (`gpresult /r`) or Intune device
configuration reports to confirm policy application status before
querying individual endpoints.

---

### Detecting Configuration Mismatch

A Sysmon configuration mismatch, where the running configuration does
not match the intended version, typically manifests as:

- **Unexpected events:** event types or process names appearing in logs
  that should be excluded by the current configuration
- **Missing expected events:** events that should be generated by known
  activity are absent from the log
- **Event volume anomalies:** a significant increase or decrease in
  Sysmon event volume without a corresponding change in endpoint activity

When a mismatch is suspected, run `sysmon.exe -c` on the affected
endpoint to print the active configuration summary, then compare against
the reference version. If the registry value does not match the intended
artifact, force a policy refresh and re-verify.

---

### Performance Monitoring for Large Configurations

Binary registry values grow with configuration complexity. Very large
Sysmon configurations, particularly those with extensive include/exclude
rules, may marginally increase policy refresh duration on endpoints with
slow disk I/O or constrained resources.

Monitor policy refresh completion times after deploying a significantly
larger configuration. If policy refresh duration increases materially,
consider reviewing the configuration for rules that can be consolidated
or removed without reducing detection coverage.

Sysmon itself may also generate higher event volumes with expanded
configurations. Monitor Windows Event Log disk usage and event forwarding
pipeline throughput after significant configuration changes.

---

### Rolling Back a Bad Configuration

If a deployed configuration causes unexpected behaviour (excessive event
volume, missing critical events, or endpoint performance impact), roll
back by restoring the previous registry value:

**Via Group Policy:**
Revert the registry preference value in the GPO to the previous
`REG_BINARY` artifact and force a policy refresh on affected endpoints:

```powershell
gpupdate /force
```

**Via Intune:**
Update the Policy CSP profile to the previous registry value and sync
the affected devices from the Intune admin center or via:

```powershell
Start-Process -FilePath "C:\Windows\System32\deviceenroller.exe" -ArgumentList "/o"
```

**Verify rollback:**
After the policy refresh completes, re-query the registry value and
run `sysmon.exe -c` to confirm the previous configuration is active.

Maintain a version-tagged archive of `.reg` artifacts from each
configuration release to ensure previous versions are always available
for rollback without requiring re-extraction from a reference system.

---

## Disclaimer

This pattern is provided as reference material and design guidance.
Implementations may require adaptation based on environment, Sysmon
version, and policy infrastructure.

Validate all configurations in a controlled test environment before
production use.
