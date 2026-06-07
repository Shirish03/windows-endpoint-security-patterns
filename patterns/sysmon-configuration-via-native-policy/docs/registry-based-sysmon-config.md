# Registry-Based Sysmon Configuration – Technical Reference

For background on the pattern, the key observation about Sysmon's registry model,
and the high-level deployment flow, see the [pattern README](../README.md).

This document covers the registry location in detail, how to use the extraction
script, GPO deployment field values, and operational considerations.

---

## Registry Location

Sysmon configuration rules are stored at:

- **Registry Key**  
  `HKLM\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters`

- **Value Name**  
  `Rules`

- **Value Type**  
  `REG_BINARY`

The `Rules` value contains the compiled representation of the Sysmon configuration.
Sysmon reads from this value at runtime — changes to the registry value take effect
without restarting the Sysmon service or redeploying the binary.

---

## Extracting the Configuration

After importing a validated configuration on the reference system with
`sysmon.exe -c <config.xml>`, use `Export-SysmonRegistryConfig.ps1` to extract
the compiled registry value as a deployment artifact:

```powershell
# Extract the currently loaded configuration
.\Export-SysmonRegistryConfig.ps1 -OutputPath C:\SysmonArtifacts

# Import a config and extract in one step
.\Export-SysmonRegistryConfig.ps1 -ConfigXmlPath .\sysmonconfig.xml -OutputPath C:\SysmonArtifacts
```

The script writes two files to the output path:

- **`SysmonRules-<timestamp>.reg`** — the registry artifact in standard `.reg` format,
  ready to reference when configuring a Group Policy Preferences registry item
- **`SysmonRules-<timestamp>.txt`** — a deployment summary including SHA-256 hash,
  byte count, and the exact GPO field values to enter

Diff successive `.reg` exports to review configuration changes before distributing
a new policy version.

---

## GPO Deployment

When creating the Group Policy Preferences registry item targeting managed endpoints,
use these values:

| Field | Value |
|---|---|
| Action | Replace |
| Hive | `HKEY_LOCAL_MACHINE` |
| Key path | `SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters` |
| Value name | `Rules` |
| Value type | `REG_BINARY` |
| Value data | hex content from the `.reg` export |

The `Replace` action overwrites the existing value on each policy refresh, ensuring
endpoints stay in sync with the reference system configuration.

---

## Benefits

- **Decoupled lifecycles** — Sysmon binary and configuration updates are managed
  independently; a config change does not require a software deployment task
- **Improved consistency** — configuration delivery uses the same reliable policy
  refresh mechanism as all other managed registry settings
- **Faster iteration** — detection logic can be updated at policy cadence without
  waiting for redeployment cycles
- **Reduced operational overhead** — no additional tooling, agents, or distribution
  infrastructure beyond what already manages the endpoint

---

## Performance and Policy Considerations

The `Rules` registry value grows with the number and complexity of rules, filters,
and parameters in the configuration. On systems targeted by many policies, or when
the value is particularly large, policy processing may take slightly longer than
usual during refresh.

This is a property of registry-backed policy delivery in general, not specific to
Sysmon. It is typically transient and bounded by policy refresh frequency. Balance
the level of detail in the Sysmon configuration against the operational requirements
for policy refresh performance in your environment.
